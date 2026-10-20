import UIKit
import ImpressReviewCore

/// Reuse the editable Settings → Prompt Library as the single authoring
/// authority. Only a template UUID (never its private text) is kept as a local
/// preference; the live template body is read when the user explicitly Sends.
enum ImpressAIChatPromptSelection {
    static let storageKey = "ImpressV1NativeChatPromptTemplateID"

    static func selectedTemplate() -> ImpressV3PromptTemplate? {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let id = UUID(uuidString: raw) else { return nil }
        return ImpressV3PromptLibrary.load().first(where: { $0.id == id })
    }

    static func choose(_ templateID: UUID?) {
        if let templateID {
            UserDefaults.standard.set(templateID.uuidString, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        ImpressV3BackupCoordinator.markDataChanged()
    }

    static func systemText() -> String {
        selectedTemplate()?.content ??
            V3L("以第一性原理和奥卡姆剃刀分析问题，明确假设、证据与边界。不编造笔记内容。")
    }
}

/// Source-scoped native API chat. A cardID (not a mutable title) binds the
/// conversation to the existing V3 SQLite/backup authority. Local history is
/// complete; the remote request window is bounded and independently consented.
/// Ordinary Chat produces no FSRS events or Markdown writes.
@MainActor
final class ImpressAINativeChatViewController: UIViewController,
                                                UITableViewDataSource, UITextViewDelegate {
    private let sourceQuestion: String?
    private let sourceAnswer: String?
    private let sourceCardID: UUID?
    private let sourceContentRevision: Int?
    private let injectedRepository: ReviewWCDBRepository?
    private let explicitSourceKey: String?
    private let sourceVersionToken: String?
    private let noteIdentity: ImVaultFileIdentity?
    private var chatRepository: ReviewWCDBRepository?
    private var storedSession: WCDBV3ChatSession?
    private var contextReferences: [WCDBV3ChatContextReference] = []
    private var history: [WCDBV3ChatMessage] = []
    private var requestFailure: String?
    private var activeProviderID: UUID?
    /// An override belongs only to this Chat; global task defaults remain intact.
    private var selectedModelID: UUID?
    private var contextChoiceMade = false
    private var includeCardContext = false
    private var restoring = false
    private var sending = false
    private var saveChain: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?
    private var draftDebounce: Task<Void, Never>?

    private var sourceIdentity: String? {
        explicitSourceKey ?? sourceCardID.map { "card:" + $0.uuidString }
    }
    private var currentSourceVersion: String {
        sourceVersionToken ?? String(sourceContentRevision ?? -1)
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let messageInput = UITextView()
    private let sendButton = UIButton(type: .system)
    private let inputBar = UIView()
    private let privacyLabel = UILabel()
    private let contextBar = UIStackView()
    private let promptButton = UIButton(type: .system)
    private let materialButton = UIButton(type: .system)
    private var sessionPromptOverride: String?

    init(question: String? = nil, answer: String? = nil,
         cardID: UUID? = nil, contentRevision: Int? = nil,
         repository: ReviewWCDBRepository? = nil,
         sourceKey: String? = nil, sourceVersion: String? = nil,
         noteIdentity: ImVaultFileIdentity? = nil) {
        self.explicitSourceKey = sourceKey
        self.sourceVersionToken = sourceVersion
        self.noteIdentity = noteIdentity
        self.sourceQuestion = question
        self.sourceAnswer = answer
        self.sourceCardID = cardID
        self.sourceContentRevision = contentRevision
        self.injectedRepository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        draftDebounce?.cancel()
        enqueuePersistence()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshModelPicker()
    }

    private func liveRoute() throws -> ImpressAIResolvedRoute {
        let registry = ImpressAIConfigStore.shared.registry
        if let selectedModelID {
            guard let model = registry.models.first(where: { $0.id == selectedModelID }),
                  let connection = registry.connections.first(where: {
                      $0.id == model.connectionID
                  }) else { throw ImpressAIContractError.invalidRoute }
            let route = ImpressAIResolvedRoute(connection: connection, model: model)
            try ImpressAIRequestPolicy.validate(route)
            return route
        }
        return try registry.resolve(.conversation)
    }

    private func refreshModelPicker() {
        let current = try? liveRoute()
        navigationItem.prompt = current.map {
            $0.connection.title + " · " + $0.model.identifier
        } ?? V3L("请先配置可用的对话模型")
        let model = UIBarButtonItem(title: V3L("模型"), style: .plain,
            target: self, action: #selector(chooseConversationModel))
        model.accessibilityIdentifier = "impress.ai.chat.model-picker"
        let old = UIBarButtonItem(image: UIImage(systemName: "clock.arrow.circlepath"),
            style: .plain, target: self, action: #selector(openDiscussionHistory))
        old.accessibilityIdentifier = "impress.ai.chat.history"
        old.accessibilityLabel = V3L("历史讨论")
        let fresh = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"),
            style: .plain, target: self, action: #selector(startNewDiscussion))
        fresh.accessibilityIdentifier = "impress.ai.chat.new-discussion"
        fresh.accessibilityLabel = V3L("新建讨论")
        navigationItem.rightBarButtonItems = [fresh, old, model]
    }

    @objc private func chooseConversationModel() {
        // A session override must never change the global default route.
        let picker = ImpressAIModelChooser(task: .conversation,
            selectedOverrideID: selectedModelID) { [weak self] picked in
                self?.selectedModelID = picked
                self?.refreshModelPicker()
            }
        navigationController?.pushViewController(picker, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("AI 讨论")
        view.backgroundColor = ImpressV3Appearance.page
        navigationItem.largeTitleDisplayMode = .never

        tableView.dataSource = self
        tableView.register(ImpressChatMessageCell.self, forCellReuseIdentifier: "chat.message")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.keyboardDismissMode = .interactive
        tableView.accessibilityIdentifier = "impress.ai.chat.transcript"

        privacyLabel.font = ImpressV3Appearance.Typography.caption
        privacyLabel.adjustsFontForContentSizeCategory = true
        privacyLabel.numberOfLines = 2
        privacyLabel.textColor = ImpressV3Appearance.secondaryText
        privacyLabel.textAlignment = .center
        privacyLabel.text = noteIdentity != nil && sourceAnswer == nil
            ? V3L("此笔记正文较长：当前未附带全文，只显示来源名称。请先选择所需片段；不会暗中截断或发送。")
            : V3L("对话与草稿保存在本机；只有点击发送并确认材料后才会发送给服务商。不会自动写入 Obsidian。")

        messageInput.font = ImpressV3Appearance.Typography.body
        messageInput.adjustsFontForContentSizeCategory = true
        messageInput.textColor = ImpressV3Appearance.primaryText
        messageInput.backgroundColor = ImpressV3Appearance.surface
        messageInput.layer.cornerRadius = ImpressV3Appearance.Radius.field
        messageInput.textContainerInset = UIEdgeInsets(
            top: ImpressV3Appearance.Metrics.fieldPadding,
            left: ImpressV3Appearance.Metrics.fieldPadding,
            bottom: ImpressV3Appearance.Metrics.fieldPadding,
            right: ImpressV3Appearance.Metrics.fieldPadding)
        messageInput.delegate = self
        messageInput.accessibilityLabel = V3L("消息内容")
        messageInput.accessibilityIdentifier = "impress.ai.chat.input"
        ImpressSpeechAccessory.install(on: messageInput)

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.image = UIImage(systemName: "arrow.up")
            config.cornerStyle = .capsule
            config.buttonSize = .large
            config.baseBackgroundColor = ImpressV3Appearance.accent
            config.baseForegroundColor = ImpressV3Appearance.primaryButtonText
            sendButton.configuration = config
        } else {
            sendButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        }
        sendButton.addTarget(self, action: #selector(submitOrStopMessage), for: .touchUpInside)
        sendButton.accessibilityLabel = V3L("发送消息")
        sendButton.accessibilityIdentifier = "impress.ai.chat.send"
        sendButton.isEnabled = false

        inputBar.backgroundColor = .clear
        contextBar.axis = .horizontal
        contextBar.distribution = .fillEqually
        contextBar.spacing = ImpressV3Appearance.Metrics.rowSpacing
        for (button, symbol, label, action) in [
            (promptButton, "text.alignleft", V3L("提示词"), #selector(openSessionPrompt)),
            (materialButton, "doc.on.doc", V3L("本次材料"), #selector(reviewSessionMaterials))
        ] {
            ImpressV3Appearance.styleQuietButton(button, title: label, symbol: symbol)
            button.addTarget(self, action: action, for: .touchUpInside)
            contextBar.addArrangedSubview(button)
        }
        promptButton.accessibilityIdentifier = "impress.ai.chat.prompt"
        materialButton.accessibilityIdentifier = "impress.ai.chat.materials"
        for element in [tableView, inputBar, privacyLabel, contextBar] {
            element.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(element)
        }
        for element in [messageInput, sendButton] {
            element.translatesAutoresizingMaskIntoConstraints = false
            inputBar.addSubview(element)
        }
        NSLayoutConstraint.activate([
            contextBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            contextBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: ImpressV3Appearance.Metrics.screenInset),
            contextBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -ImpressV3Appearance.Metrics.screenInset),
            contextBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),
            tableView.topAnchor.constraint(equalTo: contextBar.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: privacyLabel.topAnchor, constant: -6),

            privacyLabel.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            privacyLabel.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            privacyLabel.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -6),

            inputBar.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: ImpressV3Appearance.Metrics.screenInset),
            inputBar.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -ImpressV3Appearance.Metrics.screenInset),
            inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            inputBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            inputBar.heightAnchor.constraint(lessThanOrEqualToConstant: 110),

            messageInput.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor),
            messageInput.topAnchor.constraint(equalTo: inputBar.topAnchor),
            messageInput.bottomAnchor.constraint(equalTo: inputBar.bottomAnchor),
            sendButton.leadingAnchor.constraint(equalTo: messageInput.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor),
            sendButton.centerYAnchor.constraint(equalTo: messageInput.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 48),
            sendButton.heightAnchor.constraint(equalToConstant: 48),
            messageInput.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
        Task { await restoreLocalSession() }
    }

    func textViewDidChange(_ textView: UITextView) {
        let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        sendButton.isEnabled = sending || (!restoring && !content.isEmpty &&
            content.utf8.count <= 12_000)
        sendButton.configuration?.image = UIImage(systemName: sending ? "stop.fill" : "arrow.up")
        sendButton.accessibilityLabel = sending ? V3L("停止生成") : V3L("发送消息")
        guard !restoring else { return }
        draftDebounce?.cancel()
        draftDebounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            self?.enqueuePersistence()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        history.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "chat.message", for: indexPath)
            as! ImpressChatMessageCell
        cell.configure(history[indexPath.row])
        return cell
    }

    @objc private func openSessionPrompt() {
        guard !sending && !restoring else { return }
        let picker = UIAlertController(title: V3L("本次讨论提示词"),
            message: V3L("选择只影响当前讨论的后续消息，不会覆盖全局模板。"),
            preferredStyle: .actionSheet)
        picker.addAction(UIAlertAction(title: V3L("默认：第一性原理 + 奥卡姆剃刀"),
            style: .default) { [weak self] _ in
            self?.sessionPromptOverride = nil
            self?.enqueuePersistence()
        })
        for item in ImpressV3PromptLibrary.load() {
            picker.addAction(UIAlertAction(title: item.title, style: .default) { [weak self] _ in
                self?.previewPrompt(title: item.title, text: item.content)
            })
        }
        picker.addAction(UIAlertAction(title: V3L("编辑本次提示词"),
            style: .default) { [weak self] _ in
            guard let self else { return }
            let editor = UIAlertController(title: V3L("临时提示词"),
                message: V3L("仅在本次讨论使用。可在设置的提示词库长期编辑模板。"),
                preferredStyle: .alert)
            editor.addTextField { $0.text = self.sessionPromptOverride ??
                ImpressAIChatPromptSelection.systemText() }
            editor.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
            editor.addAction(UIAlertAction(title: V3L("本次使用"), style: .default) { [weak self, weak editor] _ in
                let value = editor?.textFields?.first?.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !value.isEmpty else { return }
                self?.sessionPromptOverride = value
                self?.enqueuePersistence()
            })
            self.present(editor, animated: true)
        })
        picker.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        picker.popoverPresentationController?.sourceView = promptButton
        present(picker, animated: true)
    }

    private func previewPrompt(title: String, text: String) {
        let alert = UIAlertController(title: title,
            message: String(text.prefix(1000)), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: V3L("本次使用"), style: .default) {
            [weak self] _ in
            self?.sessionPromptOverride = text
            self?.enqueuePersistence()
        })
        present(alert, animated: true)
    }

    @objc private func reviewSessionMaterials() {
        guard !sending && !restoring else { return }
        let preview = contextReferences.map {
            $0.stableIdentity + "\n" + String($0.excerpt.prefix(350))
        }.joined(separator: "\n\n")
        let alert = UIAlertController(title: V3L("本次引用材料"),
            message: preview.isEmpty
                ? V3L("没有选中材料。打开对话不自动上传私人内容；首次发送可选择当前卡片。")
                : preview,
            preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: V3L("移除引用材料"),
            style: .destructive) { [weak self] _ in
            self?.includeCardContext = false
            self?.contextChoiceMade = true
            self?.contextReferences = []
            self?.enqueuePersistence()
        })
        alert.addAction(UIAlertAction(title: V3L("下次发送时重新选择"),
            style: .default) { [weak self] _ in
            self?.includeCardContext = false
            self?.contextChoiceMade = false
            self?.contextReferences = []
            self?.enqueuePersistence()
        })
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.popoverPresentationController?.sourceView = materialButton
        present(alert, animated: true)
    }

    private enum ChatFlowError: LocalizedError {
        case localSaveFailed, sourceChanged
        var errorDescription: String? {
            switch self {
            case .localSaveFailed:
                return V3L("本地聊天保存失败，未向模型发送。")
            case .sourceChanged:
                return V3L("卡片内容已更新。请返回卡片后重新进入讨论，避免使用过期答案。")
            }
        }
    }

    @objc private func submitOrStopMessage() {
        if sending {
            // Cancels the in-flight Task/URLSession request; never executes a
            // partial response or silently retries against a billed model.
            requestTask?.cancel()
            return
        }
        submitMessage()
    }

    @objc private func submitMessage() {
        let text = messageInput.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.count <= 12_000,
              !sending, !restoring else { return }
        let route: ImpressAIResolvedRoute
        do { route = try liveRoute() }
        catch {
            let explanation: String
            switch error as? ImpressAIContractError {
            case .missingCredential:
                explanation = V3L("所选对话模型尚未保存 API Key，请打开该连接填写密钥。")
            case .disabled:
                explanation = V3L("所选模型或连接已停用，请重新选择有效模型。")
            case .freeModelQAOnly:
                explanation = V3L("当前连接属于 OpenCode 免费 QA，请选择此连接允许的模型。")
            default:
                explanation = V3L("请先在「设置 → AI 服务 → 业务默认模型」选择可用的对话模型。")
            }
            let alert = UIAlertController(title: V3L("无法使用当前对话模型"),
                message: explanation, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
            alert.addAction(UIAlertAction(title: V3L("打开 AI 服务"),
                style: .default) { [weak self] _ in
                    self?.navigationController?.pushViewController(
                        ImpressAISettingsViewController(), animated: true)
                })
            present(alert, animated: true)
            return
        }

        if let previous = activeProviderID, previous != route.connection.id,
           history.contains(where: { $0.status == .completed }) {
            let warning = UIAlertController(
                title: V3L("切换 AI 服务商"),
                message: V3L("此次请求会把近期对话材料发送给新服务商，是否同意？"),
                preferredStyle: .alert)
            warning.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
            warning.addAction(UIAlertAction(title: V3L("同意并发送"),
                                            style: .default) { [weak self] _ in
                self?.chooseSourceContext(text, route: route)
            })
            present(warning, animated: true)
            return
        }
        chooseSourceContext(text, route: route)
    }

    private func chooseSourceContext(_ text: String,
                                     route: ImpressAIResolvedRoute) {
        if !contextChoiceMade, let question = sourceQuestion, !question.isEmpty {
            let confirm = UIAlertController(title: noteIdentity == nil
                ? V3L("是否附带当前卡片？") : V3L("是否附带当前笔记材料？"),
                message: noteIdentity == nil
                    ? V3L("只有确认后，才会发送当前卡片的问题与答案。")
                    : V3L("只有确认后，才会发送本次明确载入的笔记材料。过长笔记不会自动发送全文。"),
                preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
            confirm.addAction(UIAlertAction(title: V3L("仅发送输入内容"),
                                            style: .default) { [weak self] _ in
                guard let self else { return }
                contextChoiceMade = true
                includeCardContext = false
                contextReferences = []
                performSend(text, route: route)
            })
            confirm.addAction(UIAlertAction(title: noteIdentity == nil
                ? V3L("附带当前卡片") : V3L("附带本次笔记材料"),
                                            style: .default) { [weak self] _ in
                guard let self else { return }
                contextChoiceMade = true
                includeCardContext = true
                if let identity = sourceIdentity {
                    contextReferences = [WCDBV3ChatContextReference(
                        stableIdentity: identity,
                        sourceRevision: currentSourceVersion,
                        excerpt: question + "\n" + (sourceAnswer ?? ""))]
                }
                performSend(text, route: route)
            })
            present(confirm, animated: true)
        } else {
            performSend(text, route: route)
        }
    }

    private func performSend(_ message: String, route: ImpressAIResolvedRoute) {
        guard !sending, !restoring else { return }
        draftDebounce?.cancel()
        sending = true
        let prompt = sessionPromptOverride ?? ImpressAIChatPromptSelection.systemText()
        let providerID = route.connection.id
        let modelName = route.model.identifier
        var system = prompt
        if includeCardContext, let question = sourceQuestion, !question.isEmpty {
            system += "\n" + (noteIdentity == nil
                ? V3L("当前卡片的问题：") : V3L("当前笔记来源：")) + question
            if let answer = sourceAnswer, !answer.isEmpty {
                system += "\n" + (noteIdentity == nil
                    ? V3L("当前卡片的参考答案：") : V3L("本次已授权笔记正文：")) + answer
            }
        }
        let messageID = UUID()
        history.append(WCDBV3ChatMessage(
            messageID: messageID, role: .user, text: message,
            status: .pending, providerID: providerID,
            modelIdentifier: modelName, promptSnapshot: prompt))
        messageInput.text = ""
        privacyLabel.text = V3L("正在请求模型…")
        sendButton.isEnabled = true
        sendButton.configuration?.image = UIImage(systemName: "stop.fill")
        sendButton.accessibilityLabel = V3L("停止生成")
        reloadAndScroll()

        let priorSave = saveChain
        requestTask = Task {
            await priorSave?.value
            do {
                try Task.checkCancellation()
                // Re-check the authorized Vault and content SHA immediately
                // before any note context is sent to a remote provider.
                if self.includeCardContext, let noteID = self.noteIdentity,
                   let expectedSHA = self.sourceVersionToken {
                    let current: ImVaultRawDocument = try await withCheckedThrowingContinuation {
                        (continuation: CheckedContinuation<ImVaultRawDocument, Error>) in
                        ImVaultReadSync.shared.read(noteID) { result in
                            continuation.resume(with: result)
                        }
                    }
                    guard current.digest == expectedSHA else {
                        throw ChatFlowError.sourceChanged
                    }
                }
                // The current card can change while this controller is open.
                // Never transmit or grade using a stale identity/revision.
                if let id = sourceCardID, let revision = sourceContentRevision {
                    let store = try chatRepository ?? injectedRepository ??
                        ImpressV3ReviewEnvironment.repository()
                    guard let card = try await store.content(for: id),
                          card.contentRevision == revision else {
                        throw ChatFlowError.sourceChanged
                    }
                }
                guard await persistLocal() else { throw ChatFlowError.localSaveFailed }
                let earlier = history.filter {
                    $0.messageID != messageID && $0.status == .completed
                }.suffix(16)
                let safeWindow = earlier.drop(while: { $0.role != .user })
                var turns = safeWindow.map { saved in
                    ImpressAIChatTurn(
                        role: saved.role == .user ? .user : .assistant,
                        text: saved.text)
                }
                turns.append(ImpressAIChatTurn(role: .user, text: message))
                let reply = try await ImpressAIHTTPClient.shared.converse(
                    route: route, system: system, turns: turns)
                try Task.checkCancellation()
                if let index = history.firstIndex(where: { $0.messageID == messageID }) {
                    history[index].status = .completed
                }
                history.append(WCDBV3ChatMessage(
                    role: .assistant, text: reply, status: .completed,
                    providerID: providerID, modelIdentifier: modelName,
                    promptSnapshot: prompt))
                activeProviderID = providerID
                requestFailure = nil
                privacyLabel.text = V3L("对话已保存至本机；更新内容仍需预览确认。")
            } catch {
                let cancelled = Task.isCancelled || error is CancellationError
                if let index = history.firstIndex(where: { $0.messageID == messageID }) {
                    history[index].status = cancelled ? .cancelled : .failed
                }
                requestFailure = cancelled ? V3L("生成已停止") : error.localizedDescription
                if messageInput.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messageInput.text = message
                }
                privacyLabel.text = cancelled
                    ? V3L("已停止生成；原始输入和历史仍保留在本机。")
                    : V3L("请求失败，输入内容已保留。")
                if !cancelled { showProblem(error) }
            }
            enqueuePersistence()
            await saveChain?.value
            sending = false
            requestTask = nil
            textViewDidChange(messageInput)
            reloadAndScroll()
        }
    }

    private func restoreLocalSession() async {
        guard let identity = sourceIdentity else {
            textViewDidChange(messageInput)
            return
        }
        restoring = true
        defer {
            restoring = false
            textViewDidChange(messageInput)
        }
        do {
            let repo = try injectedRepository ?? ImpressV3ReviewEnvironment.repository()
            chatRepository = repo
            let sessions = try await repo.chatSessions(for: identity)
            if let latest = sessions.first {
                activateSession(latest)
                if history != latest.messages { enqueuePersistence() }
            }
        } catch {
            privacyLabel.text = V3L("本地聊天恢复失败。请保留当前页面，不要覆盖历史。")
        }
    }

    private func activateSession(_ session: WCDBV3ChatSession) {
        storedSession = session
        sessionPromptOverride = session.promptOverride
        history = session.messages
        for i in history.indices where history[i].status == .pending {
            history[i].status = .failed // No auto-replay after interruption.
        }
        messageInput.text = session.inputDraft
        contextReferences = session.contextReferences
        requestFailure = session.requestError
        let approved = contextReferences.first(where: { $0.stableIdentity == sourceIdentity })
        let stillCurrent = approved?.sourceRevision == currentSourceVersion
        includeCardContext = approved != nil && stillCurrent
        contextChoiceMade = includeCardContext
        if approved != nil && !stillCurrent {
            privacyLabel.text = V3L("来源内容有更新；发送前请重新确认引用范围。")
        }
        activeProviderID = history.reversed().compactMap(\.providerID).first
        selectedModelID = nil
        if let prior = history.reversed().first(where: {
            $0.providerID != nil && $0.modelIdentifier != nil
        }), let connectionID = prior.providerID, let modelName = prior.modelIdentifier {
            let registry = ImpressAIConfigStore.shared.registry
            selectedModelID = registry.models.first(where: { item in
                item.identifier == modelName && registry.connections.contains(where: {
                    $0.id == connectionID && $0.id == item.connectionID
                })
            })?.id
        }
        refreshModelPicker()
        reloadAndScroll()
    }

    // Flush draft/CAS before changing session IDs. Never overwrite an old row
    // with a newly created empty transcript or a concurrently changed record.
    private func flushBeforeSwitch() async -> Bool {
        draftDebounce?.cancel()
        await saveChain?.value
        if storedSession == nil && history.isEmpty &&
           messageInput.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return await persistLocal()
    }

    @objc private func openDiscussionHistory() {
        guard !restoring && !sending, let identity = sourceIdentity,
              let repository = chatRepository else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let sessions = try await repository.chatSessions(for: identity)
                let page = ImpressChatSessionHistoryViewController(
                    sessions: sessions, currentSessionID: self.storedSession?.sessionID)
                page.onSelect = { [weak self] id in self?.switchDiscussion(to: id) }
                self.navigationController?.pushViewController(page, animated: true)
            } catch { self.showProblem(error) }
        }
    }

    @objc private func startNewDiscussion() {
        guard !restoring && !sending, let identity = sourceIdentity,
              let repository = chatRepository else { return }
        restoring = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.restoring = false; self.textViewDidChange(self.messageInput) }
            guard await self.flushBeforeSwitch() else {
                self.privacyLabel.text = V3L("当前聊天保存失败；已阻止新建，避免丢失草稿。")
                return
            }
            do {
                let fresh = WCDBV3ChatSession(sourceIdentity: identity)
                try await repository.saveChatSession(fresh, expectedRevision: nil)
                self.activateSession(fresh)
                self.privacyLabel.text = V3L("新讨论已创建。旧会话仍可从历史讨论打开。")
            } catch { self.showProblem(error) }
        }
    }

    private func switchDiscussion(to id: UUID) {
        guard !restoring && !sending, let identity = sourceIdentity,
              let repository = chatRepository else { return }
        restoring = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.restoring = false; self.textViewDidChange(self.messageInput) }
            guard await self.flushBeforeSwitch() else {
                self.privacyLabel.text = V3L("当前聊天保存失败；已阻止切换，避免覆盖旧会话。")
                return
            }
            do {
                // Re-read authoritative row instead of using a possibly stale
                // snapshot from the history list.
                let all = try await repository.chatSessions(for: identity)
                guard let chosen = all.first(where: { $0.sessionID == id }) else {
                    throw WCDBV3ChatStorageError.invalidRecord
                }
                self.activateSession(chosen)
                self.navigationController?.popViewController(animated: true)
                if self.history != chosen.messages { self.enqueuePersistence() }
            } catch { self.showProblem(error) }
        }
    }

    private func enqueuePersistence() {
        guard sourceIdentity != nil, chatRepository != nil else { return }
        let previous = saveChain
        saveChain = Task { [self] in
            await previous?.value
            _ = await persistLocal()
        }
    }

    /// Serial actor-backed CAS. This persists all local turns, not just the
    /// bounded suffix supplied to the remote model.
    private func persistLocal() async -> Bool {
        guard let identity = sourceIdentity, let repository = chatRepository else {
            return sourceIdentity == nil
        }
        let base = storedSession ?? WCDBV3ChatSession(sourceIdentity: identity)
        if storedSession != nil && base.messages == history &&
           base.inputDraft == messageInput.text &&
           base.contextReferences == contextReferences &&
           base.requestError == requestFailure &&
           base.promptOverride == sessionPromptOverride { return true }
        var next = base
        next.messages = history
        next.inputDraft = messageInput.text ?? ""
        next.contextReferences = contextReferences
        next.requestError = requestFailure
        next.promptOverride = sessionPromptOverride
        next.updatedAt = Date()
        next.revision = storedSession == nil ? 0 : base.revision + 1
        do {
            try await repository.saveChatSession(
                next, expectedRevision: storedSession?.revision)
            storedSession = next
            return true
        } catch {
            privacyLabel.text = V3L("本地聊天保存失败。未能确认草稿或对话已保存。")
            return false
        }
    }

    private func showProblem(_ error: Error) {
        let alert = UIAlertController(title: V3L("AI 对话失败"),
            message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        if presentedViewController == nil { present(alert, animated: true) }
    }

    private func reloadAndScroll() {
        tableView.reloadData()
        if !history.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: history.count - 1, section: 0),
                                  at: .bottom, animated: false)
        }
    }
}

@MainActor
final class ImpressChatSessionHistoryViewController: UITableViewController {
    private let sessions: [WCDBV3ChatSession]
    private let currentSessionID: UUID?
    var onSelect: ((UUID) -> Void)?

    init(sessions: [WCDBV3ChatSession], currentSessionID: UUID?) {
        self.sessions = sessions
        self.currentSessionID = currentSessionID
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("历史讨论")
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.rowHeight = UITableView.automaticDimension
        tableView.accessibilityIdentifier = "impress.ai.chat.history-list"
        if sessions.isEmpty {
            let label = UILabel()
            label.text = V3L("还没有历史讨论；创建新讨论不会删除旧会话。")
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = ImpressV3Appearance.Typography.body
            label.textColor = ImpressV3Appearance.secondaryText
            tableView.backgroundView = label
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sessions.count
    }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let session = sessions[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "chat.history")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "chat.history")
        let first = session.messages.first(where: { $0.role == .user })?.text ??
            (session.inputDraft.isEmpty ? V3L("空白讨论") : session.inputDraft)
        var config = UIListContentConfiguration.subtitleCell()
        config.text = String(first.prefix(100))
        config.secondaryText = DateFormatter.localizedString(
            from: session.updatedAt, dateStyle: .medium, timeStyle: .short) +
            " · " + String(session.messages.count) + " " + V3L("条消息")
        config.textProperties.numberOfLines = 2
        config.textProperties.font = ImpressV3Appearance.Typography.body
        config.secondaryTextProperties.font = ImpressV3Appearance.Typography.caption
        cell.contentConfiguration = config
        cell.backgroundColor = ImpressV3Appearance.surface
        cell.accessoryType = session.sessionID == currentSessionID ? .checkmark : .disclosureIndicator
        cell.accessibilityIdentifier = "impress.ai.chat.history-row"
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard sessions.indices.contains(indexPath.row) else { return }
        onSelect?(sessions[indexPath.row].sessionID)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

@MainActor
final class ImpressChatMessageCell: UITableViewCell {
    private let roleLabel = UILabel()
    private let bodyView = UITextView()
    private let stateLabel = UILabel()
    private let column = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        column.axis = .vertical
        column.spacing = ImpressV3Appearance.Metrics.rowSpacing
        column.translatesAutoresizingMaskIntoConstraints = false
        roleLabel.font = ImpressV3Appearance.Typography.caption
        roleLabel.textColor = ImpressV3Appearance.secondaryText
        bodyView.backgroundColor = .clear
        bodyView.isEditable = false
        bodyView.isSelectable = true
        bodyView.isScrollEnabled = false
        bodyView.textContainerInset = .zero
        bodyView.textContainer.lineFragmentPadding = 0
        bodyView.font = ImpressV3Appearance.Typography.body
        bodyView.textColor = ImpressV3Appearance.primaryText
        bodyView.adjustsFontForContentSizeCategory = true
        bodyView.accessibilityIdentifier = "impress.ai.chat.message-body"
        stateLabel.font = ImpressV3Appearance.Typography.caption
        stateLabel.textColor = ImpressV3Appearance.secondaryText
        stateLabel.numberOfLines = 0
        for item in [roleLabel, bodyView, stateLabel] {
            column.addArrangedSubview(item)
        }
        contentView.addSubview(column)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: margins.topAnchor, constant: 4),
            column.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -4),
            column.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: margins.trailingAnchor)
        ])
        selectionStyle = .none
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    func configure(_ message: WCDBV3ChatMessage) {
        roleLabel.text = message.role == .user ? V3L("我") : V3L("AI")
        let rendered = MarkdownKitRenderer().parseMarkdown(message.text)
            ?? NSAttributedString(string: message.text)
        bodyView.attributedText = rendered
        bodyView.isSelectable = true
        stateLabel.text = message.status == .failed ? V3L("请求失败，可重新发送") :
            (message.status == .cancelled ? V3L("请求已取消") :
             (message.status == .pending ? V3L("正在生成…") : nil))
        stateLabel.isHidden = stateLabel.text == nil
        backgroundColor = message.role == .user
            ? ImpressV3Appearance.reviewActionSurface : ImpressV3Appearance.surface
    }
}
