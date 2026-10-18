import UIKit
import Speech
import AVFoundation
import CoreMedia

// V3.3: This unit is the only authority for microphone capture and Apple
// on-device speech-analysis sessions. It never persists audio or transcripts.
enum ImpressSpeechLocale: String, CaseIterable {
    case chineseSimplified = "zh-CN"
    case chineseTraditional = "zh-TW"
    case english = "en-US"

    static let storageKey = "ImpressV3SpeechInputLocale"
    static func selected(in defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .chineseSimplified
    }
    var locale: Locale { Locale(identifier: rawValue) }
    var name: String {
        switch self {
        case .chineseSimplified: return V3L("普通话（简体）")
        case .chineseTraditional: return V3L("中文（繁体）")
        case .english: return "English (US)"
        }
    }
}

enum ImpressSpeechFailure: LocalizedError {
    case busy, denied, unsupported, modelRequired, unavailableMicrophone
    case noFinalText, canceled, recordingInterrupted

    var errorDescription: String? {
        switch self {
        case .busy: return V3L("另一个语音输入会话仍在进行。")
        case .denied: return V3L("麦克风未授权，可在 iOS 设置中启用。")
        case .unsupported: return V3L("此设备或识别语言没有可用的 Apple 端侧语音模型。")
        case .modelRequired: return V3L("该语言需要先下载 Apple 端侧识别模型。")
        case .unavailableMicrophone: return V3L("无法访问麦克风，请在真机检查录音设备。")
        case .noFinalText: return V3L("没有获得可插入的最终识别文本。")
        case .canceled: return V3L("本次语音输入已取消。")
        case .recordingInterrupted: return V3L("语音输入被系统中断。原有文字没有改变。")
        }
    }
}

/// Results are keyed by their source audio time, not appended on every
/// callback. This prevents volatile updates from duplicating a phrase.
struct ImpressTranscriptBuffer {
    private struct Segment {
        let key: String
        var text: String
        var final: Bool
        let order: Int
    }
    private var segments: [String: Segment] = [:]
    private var order = 0

    mutating func accept(key: String, text: String, isFinal: Bool) {
        guard !text.isEmpty else { return }
        if var previous = segments[key] {
            guard !previous.final else { return }
            previous.text = text
            previous.final = isFinal
            segments[key] = previous
        } else {
            segments[key] = Segment(key: key, text: text, final: isFinal, order: order)
            order += 1
        }
    }

    var finalText: String {
        ordered.filter(\.final).map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var previewText: String {
        ordered.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var ordered: [Segment] {
        segments.values.sorted { $0.order < $1.order }
    }
}

@MainActor
final class ImpressSpeechService: NSObject {
    static let shared = ImpressSpeechService()

    enum State {
        case idle, preparing, recording, finishing
    }
    enum EngineName: String {
        case speech = "SpeechTranscriber"
        case dictation = "DictationTranscriber"
    }
    struct Availability {
        let engine: EngineName?
        let actualLocale: Locale?
        let installed: Bool
    }

    private enum Recognizer {
        case speech(SpeechTranscriber)
        case dictation(DictationTranscriber)
        var modules: [any SpeechModule] {
            switch self {
            case .speech(let r): return [r]
            case .dictation(let r): return [r]
            }
        }
    }

    private(set) var state = State.idle
    private var analyzer: SpeechAnalyzer?
    private var capture: CaptureInputSequenceProvider?
    private var resultTask: Task<Void, Never>?
    private var segments = ImpressTranscriptBuffer()
    private var updateHandler: ((String, String) -> Void)?
    private var observedApplication = false

    private override init() { super.init() }

    func availability(for choice: ImpressSpeechLocale) async -> Availability {
        if SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: choice.locale) {
            let installed = await SpeechTranscriber.installedLocales
            return Availability(engine: .speech, actualLocale: locale,
                installed: installed.contains(where: { $0.identifier == locale.identifier }))
        }
        if let locale = await DictationTranscriber.supportedLocale(equivalentTo: choice.locale) {
            let installed = await DictationTranscriber.installedLocales
            return Availability(engine: .dictation, actualLocale: locale,
                installed: installed.contains(where: { $0.identifier == locale.identifier }))
        }
        return Availability(engine: nil, actualLocale: nil, installed: false)
    }

    private func recognizer(for choice: ImpressSpeechLocale) async throws -> Recognizer {
        let capability = await availability(for: choice)
        guard let locale = capability.actualLocale else { throw ImpressSpeechFailure.unsupported }
        switch capability.engine {
        case .speech: return .speech(SpeechTranscriber(locale: locale, preset: .transcription))
        case .dictation: return .dictation(DictationTranscriber(locale: locale, preset: .progressiveLongDictation))
        case nil: throw ImpressSpeechFailure.unsupported
        }
    }

    /// Explicit user action. Never initiate network/model download at launch.
    func downloadModel(for choice: ImpressSpeechLocale) async throws {
        let engine = try await recognizer(for: choice)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: engine.modules) {
            try await request.downloadAndInstall()
        }
    }

    func start(choice: ImpressSpeechLocale,
               onUpdate: @escaping (String, String) -> Void) async throws {
        guard case .idle = state else { throw ImpressSpeechFailure.busy }
        state = .preparing
        updateHandler = onUpdate
        segments = ImpressTranscriptBuffer()
        do {
            guard await AVAudioApplication.requestRecordPermission() else {
                throw ImpressSpeechFailure.denied
            }
            let engine = try await recognizer(for: choice)
            let installed = await availability(for: choice)
            guard installed.installed else { throw ImpressSpeechFailure.modelRequired }
            guard let device = AVCaptureDevice.default(for: .audio) else {
                throw ImpressSpeechFailure.unavailableMicrophone
            }
            let provider = try await CaptureInputSequenceProvider.providerWithSession(
                from: device, compatibleWith: engine.modules)
            let analysis = SpeechAnalyzer(modules: engine.modules)
            self.capture = provider
            self.analyzer = analysis
            switch engine {
            case .speech(let transcriber):
                resultTask = Task { [weak self] in
                    do {
                        for try await result in transcriber.results {
                            self?.receive(String(result.text.characters),
                                range: result.range, final: result.isFinal)
                        }
                    } catch { self?.receiveFailure(error) }
                }
            case .dictation(let transcriber):
                resultTask = Task { [weak self] in
                    do {
                        for try await result in transcriber.results {
                            self?.receive(String(result.text.characters),
                                range: result.range, final: result.isFinal)
                        }
                    } catch { self?.receiveFailure(error) }
                }
            }
            try await analysis.start(inputSequence: provider.analyzerInputs)
            // Capture startup is not allowed to block the UIKit thread.
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    provider.captureSession.startRunning()
                    continuation.resume()
                }
            }
            guard provider.captureSession.isRunning else {
                throw ImpressSpeechFailure.unavailableMicrophone
            }
            state = .recording
            observeInterruption()
        } catch {
            await cancel()
            throw error
        }
    }

    private func receive(_ value: String, range: CMTimeRange, final: Bool) {
        guard case .recording = state else {
            guard case .finishing = state else { return }
            let key = String(range.start.value) + "/" + String(range.start.timescale)
            segments.accept(key: key, text: value, isFinal: final)
            updateHandler?(segments.finalText, segments.previewText)
            return
        }
        let key = String(range.start.value) + "/" + String(range.start.timescale)
        segments.accept(key: key, text: value, isFinal: final)
        updateHandler?(segments.finalText, segments.previewText)
    }

    private func receiveFailure(_ error: Error) {
        guard case .recording = state else { return }
        // No log line ever includes captured speech.
        updateHandler?(segments.finalText, V3L("识别中断，请结束或取消"))
    }

    /// No draft, card, WCDB or Vault mutation occurs here.
    /// Only the UI's explicit confirm operation inserts final text.
    func finish() async throws -> String {
        guard case .recording = state, let analyzer else {
            throw ImpressSpeechFailure.canceled
        }
        state = .finishing
        if let capture {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    capture.captureSession.stopRunning()
                    continuation.resume()
                }
            }
        }
        capture = nil
        // The capture provider terminates its input stream on release. A
        // bounded watchdog prevents indefinitely waiting on an audio driver.
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { await analyzer.cancelAndFinishNow() }
        }
        defer { watchdog.cancel() }
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            // A hardware interruption can leave partial audio; do not
            // insert volatile text as an apparently final result.
        }
        await resultTask?.value
        let result = segments.finalText
        reset()
        guard !result.isEmpty else { throw ImpressSpeechFailure.noFinalText }
        return result
    }

    func cancel() async {
        if let provider = capture, provider.captureSession.isRunning {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    provider.captureSession.stopRunning()
                    continuation.resume()
                }
            }
        }
        await analyzer?.cancelAndFinishNow()
        resultTask?.cancel()
        reset()
    }

    private func reset() {
        NotificationCenter.default.removeObserver(self,
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self,
            name: AVAudioSession.interruptionNotification, object: nil)
        observedApplication = false
        capture = nil
        analyzer = nil
        resultTask = nil
        updateHandler = nil
        segments = ImpressTranscriptBuffer()
        state = .idle
    }

    private func observeInterruption() {
        guard !observedApplication else { return }
        observedApplication = true
        NotificationCenter.default.addObserver(self,
            selector: #selector(cancelOnInterruption),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(cancelOnInterruption),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    @objc private func cancelOnInterruption() {
        Task { await cancel() }
    }
}
