import Foundation
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

/// Ephemeral, bounded preview-only material. No raw files are persisted or
/// transmitted: a provider multimodal capability/consent gateway is still
/// required before any future network upload.
@MainActor
struct ImpressChatPOCLocalPreview {
    enum Origin: String { case photo = "相册", file = "文件", camera = "拍照" }
    let id: UUID
    let title: String
    let source: Origin
    let approximateBytes: Int
    let thumbnail: UIImage?
    /// In-memory metadata-stripped bounded JPEG, never WCDB or Vault bytes.
    let jpegData: Data?

    init(id: UUID, title: String, source: Origin, approximateBytes: Int,
         thumbnail: UIImage?, jpegData: Data? = nil) {
        self.id = id
        self.title = title
        self.source = source
        self.approximateBytes = approximateBytes
        self.thumbnail = thumbnail
        self.jpegData = jpegData
    }
}

/// Explicit, bounded UIKit system pickers. These items never enter SSE,
/// WCDB, provider requests or Vault writes. UI must confirm a future upload.
@MainActor
final class ImpressChatPOCLocalAttachments: NSObject,
    PHPickerViewControllerDelegate, UIDocumentPickerDelegate,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private weak var presenting: UIViewController?
    private(set) var items: [ImpressChatPOCLocalPreview] = []
    var onChange: (([ImpressChatPOCLocalPreview]) -> Void)?

    private let maxItems = 5
    private let maxItemBytes = 12 * 1_024 * 1_024

    init(presenting: UIViewController) {
        self.presenting = presenting
    }

    func pickerMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "相册", image: UIImage(systemName: "photo.on.rectangle")) {
                [weak self] _ in self?.openPhotos()
            },
            UIAction(title: "文件", image: UIImage(systemName: "folder")) {
                [weak self] _ in self?.openFiles()
            },
            UIAction(title: "拍照", image: UIImage(systemName: "camera")) {
                [weak self] _ in self?.openCamera()
            }
        ])
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        onChange?(items)
    }

    func clear() {
        items.removeAll()
        onChange?(items)
    }

    /// Nil means mixed/unsupported selections or over-limit: fail closed.
    /// Returned payloads are immutable copies for one explicit Send only.
    func imagePayloadsForExplicitSend() -> [ImpressAIImagePayload]? {
        guard !items.isEmpty, items.count <= 3,
              items.allSatisfy({ $0.jpegData != nil }) else { return nil }
        let payloads = items.compactMap { item -> ImpressAIImagePayload? in
            guard let bytes = item.jpegData else { return nil }
            return ImpressAIImagePayload(jpeg: bytes, displayName: item.title)
        }
        guard payloads.count == items.count,
              payloads.reduce(0, { $0 + $1.jpeg.count }) <= 1_200_000 else {
            return nil
        }
        return payloads
    }

    #if DEBUG
    /// Deterministic unit fixture: never reads or persists device resources.
    func addSyntheticPreviewForTest(_ name: String) {
        insert(ImpressChatPOCLocalPreview(
            id: UUID(), title: name, source: .file, approximateBytes: 100,
            thumbnail: nil))
    }

    func addSyntheticImageForTest(_ name: String) {
        let painter = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = painter.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        guard let data = image.jpegData(compressionQuality: 0.7),
              let prepared = Self.boundedSendableJPEG(from: data) else { return }
        insert(ImpressChatPOCLocalPreview(id: UUID(), title: name,
            source: .photo, approximateBytes: prepared.jpeg.count,
            thumbnail: prepared.thumbnail, jpegData: prepared.jpeg))
    }
    #endif

    private func insert(_ item: ImpressChatPOCLocalPreview) {
        guard items.count < maxItems, item.approximateBytes <= maxItemBytes,
              !item.title.isEmpty else { return }
        items.append(item)
        onChange?(items)
    }

    private func capacityAvailable() -> Bool {
        if items.count < maxItems { return true }
        showNotice("一次最多预览 5 项材料；请先移除一项。")
        return false
    }

    private func openPhotos() {
        guard capacityAvailable(), let presenting else { return }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = maxItems - items.count
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenting.present(picker, animated: true)
    }

    private func openFiles() {
        guard capacityAvailable(), let presenting else { return }
        // asCopy keeps the original Files/iCloud Provider item unchanged.
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        presenting.present(picker, animated: true)
    }

    private func openCamera() {
        guard capacityAvailable(), let presenting else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showNotice("此设备没有可使用的相机。")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = self
        presenting.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController,
                didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results.prefix(maxItems - items.count) {
            let provider = result.itemProvider
            guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            else { continue }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
                [weak self] bytes, _ in
                Task { @MainActor [weak self] in
                    guard let self, let bytes, bytes.count <= self.maxItemBytes,
                          let preview = Self.boundedSendableJPEG(from: bytes) else {
                        self?.showNotice("图片超过安全大小或无法预览。")
                        return
                    }
                    self.insert(ImpressChatPOCLocalPreview(
                        id: UUID(), title: provider.suggestedName ?? "本地图片",
                        source: .photo, approximateBytes: preview.jpeg.count,
                        thumbnail: preview.thumbnail, jpegData: preview.jpeg))
                }
            }
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        for url in urls.prefix(maxItems - items.count) {
            guard url.isFileURL else { continue }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  let info = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = info[.size] as? NSNumber,
                  size.intValue <= maxItemBytes else {
                showNotice("文件超过安全大小或不可读取。")
                continue
            }
            let name = String(url.lastPathComponent.prefix(100))
            // No arbitrary document/PDF serialization. Only a verified local
            // raster may enter an explicitly approved image request.
            let supported = ["jpg", "jpeg", "png", "heic"].contains(
                url.pathExtension.lowercased())
            if supported, let bytes = try? Data(contentsOf: url),
               let preview = Self.boundedSendableJPEG(from: bytes) {
                insert(ImpressChatPOCLocalPreview(
                    id: UUID(), title: name, source: .file,
                    approximateBytes: preview.jpeg.count,
                    thumbnail: preview.thumbnail, jpegData: preview.jpeg))
            } else {
                insert(ImpressChatPOCLocalPreview(
                    id: UUID(), title: name, source: .file,
                    approximateBytes: size.intValue, thumbnail: nil))
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info:
                               [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let bytes = image.jpegData(compressionQuality: 0.72),
              bytes.count <= maxItemBytes,
              let preview = Self.boundedSendableJPEG(from: bytes) else {
            showNotice("照片无法安全预览。")
            return
        }
        insert(ImpressChatPOCLocalPreview(
            id: UUID(), title: "本地拍摄照片", source: .camera,
            approximateBytes: preview.jpeg.count,
            thumbnail: preview.thumbnail, jpegData: preview.jpeg))
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    private static func boundedSendableJPEG(from bytes: Data)
        -> (thumbnail: UIImage, jpeg: Data)? {
        guard let thumb = boundedThumbnail(from: bytes),
              let image = CGImageSourceCreateWithData(bytes as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_280,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let raster = CGImageSourceCreateThumbnailAtIndex(
            image, 0, options as CFDictionary) else { return nil }
        // This re-encode strips EXIF/GPS, fixes orientation and bounds raster
        // memory before any wire data is made. Never use the original bytes.
        let safe = UIImage(cgImage: raster)
        for quality: CGFloat in [0.68, 0.48, 0.30] {
            if let jpeg = safe.jpegData(compressionQuality: quality),
               jpeg.count <= 400_000 {
                return (thumb, jpeg)
            }
        }
        return nil
    }

    private static func boundedThumbnail(from bytes: Data) -> UIImage? {
        guard bytes.count <= 12 * 1_024 * 1_024,
              let image = CGImageSourceCreateWithData(bytes as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(image, 0, nil)
                  as NSDictionary?,
              let width = metadata[kCGImagePropertyPixelWidth] as? Int,
              let height = metadata[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              width <= 8_192, height <= 8_192,
              width * height <= 20_000_000 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(image, 0,
                                                               options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: thumb)
    }

    private func showNotice(_ detail: String) {
        guard let presenting, presenting.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "本地材料预览", message: detail,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        presenting.present(alert, animated: true)
    }
}
