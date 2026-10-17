//
//  ImAutoGenerator.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 10/5/25.
//

import Foundation
import WCDBSwift
import SystemConfiguration

class ImAutoGenerator {
    static let shared = ImAutoGenerator()

    private let kLastFetchDateKey = "kLastAutoGenerateFetchDate"
    private var timer: Timer?
    private var intervalHours: CGFloat = 1.0
    private var failureCount = 0
    private var isDisabledTemporarily = false
    private var currentModel: ImLLMModel?

    private let defaultPrompt =
        """
        角色：费曼学习教练

        任务：我提供「笔记」和「要求」，你将帮我实现如下流程。

        要求：
            1. 提问(Ask):
                - 结合「概念探究」(Concept Exploration) 与「批判延伸」(Critical Extension) 两个维度，提出 1 条深刻的问题。
                - 问题必须关联或引用原文笔记内容。
                - 问题需融合：挑战假设、建立连接、类比迁移，必须足够深度和让人引发思考。
            2. 重点提醒，仅以纯字符串的形式输出问题。

        笔记：
            \(imReplaceContentIdentifier)
        """

    private init() {}

    func start(intervalHours: CGFloat) {
        stop() // 先停止现有的
        self.intervalHours = intervalHours
        loadCurrentModel() // 确保在开始时加载当前模型

        zcLog("启动自动生成定时器，每\(intervalHours)小时检查一次")

        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: 60 * 60, target: self, selector: #selector(self.checkAndGenerate), userInfo: nil, repeats: true)
        }
    }

    func stop() {
        zcLog("停止自动生成定时器")
        timer?.invalidate()
        timer = nil
    }

    @objc private func checkAndGenerate() {
        if isDisabledTemporarily {
            zcLog("自动生成临时禁用，跳过本次检查")
            return
        }

        guard checkConditions() else { return }

        let userDefaults = UserDefaults.standard
        if let lastFetchDate = userDefaults.object(forKey: kLastFetchDateKey) as? Date {
            let elapsedTime = Date().timeIntervalSince(lastFetchDate)
            let requiredInterval = TimeInterval(intervalHours * 60 * 60)

            guard elapsedTime >= requiredInterval else {
                zcLog("未到执行时间，还需 \(Int((requiredInterval - elapsedTime) / 60)) 分钟")
                return
            }
        }

        generateOneRandomQuestion()
    }

    private func checkConditions() -> Bool {
        // 检查网络连接
        if !isNetworkAvailable() {
            zcLog("网络不可用，跳过自动生成")
            return false
        }
        // 检查是否有足够笔记
        let count = getValidNotesCount()
        if count == 0 {
            zcLog("没有有效笔记，跳过自动生成")
            // 可以考虑通知用户，但不需要每次都弹窗
            return false
        }
        return true
    }

    private func isNetworkAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }

        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }

        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        return (isReachable && !needsConnection)
    }

    private func getValidNotesCount() -> Int {
        var count = 0
        let noteMDLenght = 50 // 参考代码的阈值

        let group = DispatchGroup()
        group.enter()

        ImDBHandler.share.getRows(table: ImDBTableType.notes.description,
                                  where: (ImNoteModel.Properties.markdownText.length() > noteMDLenght)) { result in
            switch result {
            case .success(let rowsCount):
                count = rowsCount
            case .failure:
                count = 0
            }
            group.leave()
        }

        group.wait()
        return count
    }

    private func generateOneRandomQuestion() {
        zcLog("开始自动生成问题")

        let noteMDLenght = 50

        ImDBHandler.share.queryFromDB(table: ImDBTableType.notes.description,
                                      cls: ImNoteModel.self,
                                      where: (ImNoteModel.Properties.markdownText.length() > noteMDLenght)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let notes):
                guard let randomNote = notes.randomElement() else {
                    zcLog("没有有效笔记")
                    return
                }

                self.requestChat(for: randomNote)
                UserDefaults.standard.set(Date(), forKey: self.kLastFetchDateKey)
                self.resetFailureCount()

            case .failure(let error):
                self.handleFailure("查询笔记失败: \(error.localizedDescription)")
            }
        }
    }

    private func requestChat(for note: ImNoteModel) {
        guard let model = currentModel else {
            zcLog("没有可用模型，跳过自动生成")
            return
        }
        // 过滤小或空笔记
        guard let mdContent = note.markdownText, mdContent.count > 50 else {
            zcLog("当前笔记内容过少,不做操作")
            return
        }

        let fullPrompt = defaultPrompt.replacingOccurrences(of: "\(imReplaceContentIdentifier)",
                                                            with: mdContent)

        let systemPrompt = ImNetWorkRequest.shared.getCurrentSystemPrompt()
        ImNetWorkRequest.shared.requestPollingChat(
            messages: [["role": "user", "content": fullPrompt]],
            llm: model,
            systemPrompt: systemPrompt
        ) { result in
            switch result {
            case .success(let content):
                self.saveGeneratedQuestion(question: content.content, note: note)
                self.resetFailureCount()

            case .failure(let error):
                self.handleFailure("网络请求失败: \(error.localizedDescription)")
            }
        }
    }

    private func saveGeneratedQuestion(question: String, note: ImNoteModel) {
        let cleanedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuestion.isEmpty else {
            zcLog("生成的问题为空，跳过保存")
            return
        }

        var chat = ImPreChatModel()
        chat.question = cleanedQuestion
        chat.noteID = note.identifier!
        if let title = note.mainTitle {
            chat.questionSource = "\(title)"
        }
        chat.isChated = false
        chat.updateTime = Date()
        dbShare.insertToDB(intoTable: ImDBTableType.preChat.description, with: [chat])
    }

    private func handleFailure(_ message: String) {
        zcLog("自动生成失败: \(message)")

        failureCount += 1
        if failureCount >= 3 {
            zcLog("失败次数过多，临时禁用15分钟")
            disableTemporarily()
        }
    }

    private func disableTemporarily() {
        isDisabledTemporarily = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 15 * 60) {
            self.isDisabledTemporarily = false
            self.resetFailureCount()
            zcLog("自动生成重新启用")
        }
    }

    private func resetFailureCount() {
        failureCount = 0
        isDisabledTemporarily = false
    }

    private func loadCurrentModel() {
        let group = DispatchGroup()
        group.enter()

        ImDBHandler.share.queryFromDB(table: ImDBTableType.llmModel.description, cls: ImLLMModel.self) { [weak self] result in
            switch result {
            case .success(let models):
                if let defaultModel = models.first(where: { $0.isDefault == true }) {
                    self?.currentModel = defaultModel
                } else if let firstModel = models.first {
                    self?.currentModel = firstModel
                } else {
                    self?.currentModel = nil
                }
            case .failure:
                self?.currentModel = nil
            }
            group.leave()
        }

        group.wait()
    }
}
