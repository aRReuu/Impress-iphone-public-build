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
                                                UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    private let sourceQuestion: String?
    private let sourceAnswer: String?
    private let sourceCardID: UUID?
    private let sourceContentRevision: Int?
    private let injectedRepository: ReviewWCDBRepository?
    private let explicitSourceKey: String?
    private let sourceVersionToken: String?
    private let noteIdentity: ImVaultFileIdentity?
    /// Navigation-only target from a card's stable source identity.
    /// Does not authorize uploading the note or writing to its Vault.
    private let linkedNoteIdentity: ImVaultFileIdentity?
    private var chatRepository: ReviewWCDBRepository?
    private var storedSession: WCDBV3ChatSession?
    private var pendingDuplex: WCDBV3DuplexProposal?
    private var previousDuplex: [WCDBV3DuplexProposal] = []
    private var contextReferences: [WCDBV3ChatContextReference] = []
    private var history: [WCDBV3ChatMessage] = []
    private var requestFailure: String?
    private var activeProviderID: UUID?
    /// An override belongs only to this Chat; global task defaults remain intact.
    private var selectedModelID: UUID?
    private var contextChoiceMade = false
    private var contextConsentGranted = false
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
    private var noteDraftTarget: ImVaultFileIdentity? {
        noteIdentity ?? linkedNoteIdentity
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
         noteIdentity: ImVaultFileIdentity? = nil,
         linkedNoteIdentity: ImVaultFileIdentity? = nil) {
        self.linkedNoteIdentity = linkedNoteIdentity
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
        var buttons = [fresh, old, model]
        if let p = pendingDuplex, !p.state.completed {
            let pending = UIBarButtonItem(image: UIImage(systemName: "checklist"),
                style: .plain, target: self, action: #selector(resumeDuplexReview))
            pending.accessibilityIdentifier = "impress.ai.chat.pending-duplex"
            pending.accessibilityLabel = V3L("待确认的笔记与原卡修改")
            buttons.insert(pending, at: 0)
        }
        navigationItem.rightBarButtonItems = buttons
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
        tableView.delegate = self
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

    /// Display the complete user-authored prompt. A 1,000-character alert
    /// preview could conceal important instructions before user approval.
    private func previewPrompt(title: String, text: String) {
        let page = UIViewController()
        page.title = title
        page.view.backgroundColor = ImpressV3Appearance.page
        let body = UITextView()
        body.translatesAutoresizingMaskIntoConstraints = false
        body.isEditable = false
        body.isSelectable = true
        body.isScrollEnabled = true
        body.font = ImpressV3Appearance.Typography.body
        body.adjustsFontForContentSizeCategory = true
        body.textColor = ImpressV3Appearance.primaryText
        body.backgroundColor = ImpressV3Appearance.surface
        body.text = text
        body.accessibilityIdentifier = "impress.ai.chat.full-prompt-preview"
        page.view.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.topAnchor),
            body.leadingAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        page.navigationItem.rightBarButtonItem = UIBarButtonItem(
            primaryAction: UIAction(title: V3L("本次使用")) { [weak self, weak page] _ in
                self?.sessionPromptOverride = text
                self?.enqueuePersistence()
                page?.navigationController?.popViewController(animated: true)
            })
        navigationController?.pushViewController(page, animated: true)
    }

    @objc private func reviewSessionMaterials() {
        guard !sending && !restoring else { return }
        // The overview names the exact stored scope and byte count.
        // Never present a 350-character excerpt as though it is the full source.
        let preview = contextReferences.map {
            $0.stableIdentity + " · " + String($0.excerpt.utf8.count) + " bytes"
        }.joined(separator: "\n")
        let alert = UIAlertController(title: V3L("本次引用材料"),
            message: preview.isEmpty
                ? V3L("暂无引用。选择材料不会自动发送到云端。")
                : preview + (contextConsentGranted ? "\n\n" + V3L("已确认发送范围")
                             : "\n\n" + V3L("尚未确认发送范围")),
            preferredStyle: .actionSheet)
        if !contextReferences.isEmpty {
            alert.addAction(UIAlertAction(title: V3L("完整预览已选材料"),
                style: .default) { [weak self] _ in
                    self?.showFullMaterialPreview()
                })
        }
        if noteIdentity != nil {
            alert.addAction(UIAlertAction(title: V3L("选择笔记章节"),
                style: .default) { [weak self] _ in self?.openNoteSectionPicker() })
        }
        alert.addAction(UIAlertAction(title: V3L("移除引用材料"),
            style: .destructive) { [weak self] _ in
            self?.includeCardContext = false
            self?.contextChoiceMade = true
            self?.contextConsentGranted = false
            self?.contextReferences = []
            self?.enqueuePersistence()
        })
        alert.addAction(UIAlertAction(title: V3L("下次发送时重新选择"),
            style: .default) { [weak self] _ in
            self?.includeCardContext = false
            self?.contextChoiceMade = false
            self?.contextConsentGranted = false
            self?.contextReferences = []
            self?.enqueuePersistence()
        })
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.popoverPresentationController?.sourceView = materialButton
        present(alert, animated: true)
    }

    private func showFullMaterialPreview() {
        let page = UIViewController()
        page.title = V3L("本次引用材料")
        page.view.backgroundColor = ImpressV3Appearance.page
        let body = UITextView()
        body.translatesAutoresizingMaskIntoConstraints = false
        body.isEditable = false
        body.isSelectable = true
        body.font = ImpressV3Appearance.Typography.body
        body.adjustsFontForContentSizeCategory = true
        body.textColor = ImpressV3Appearance.primaryText
        body.backgroundColor = ImpressV3Appearance.surface
        body.text = contextReferences.enumerated().map { index, reference in
            String(index + 1) + ". " + reference.stableIdentity + "\n" +
            "Version: " + reference.sourceRevision + "\n" +
            String(reference.excerpt.utf8.count) + " bytes\n\n" + reference.excerpt
        }.joined(separator: "\n\n---\n\n")
        body.accessibilityIdentifier = "impress.ai.chat.full-material-preview"
        page.view.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.topAnchor),
            body.leadingAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        navigationController?.pushViewController(page, animated: true)
    }

    private func openNoteSectionPicker() {
        guard !sending && !restoring, let identity = noteIdentity else { return }
        ImVaultReadSync.shared.read(identity) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(current):
                guard current.identity == identity,
                      current.digest == self.sourceVersionToken else {
                    let alert = UIAlertController(title: V3L("来源笔记已变化"),
                        message: V3L("当前 Chat 的来源版本已过期。请返回笔记，刷新后再进入讨论。"),
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
                    self.present(alert, animated: true)
                    return
                }
                let selector = ImpressChatNoteSectionPicker(
                    sections: ImpressAISectionExtractor.sections(in: current.markdown))
                selector.onApply = { [weak self] items in
                    guard let self, let key = self.sourceIdentity else { return }
                    self.contextReferences = items.map {
                        WCDBV3ChatContextReference(stableIdentity: key,
                            sourceRevision: current.digest, excerpt: $0.text)
                    }
                    // Drafting a set of materials is not consent to send it.
                    self.includeCardContext = false
                    self.contextChoiceMade = false
                    self.contextConsentGranted = false
                    self.enqueuePersistence()
                    self.navigationController?.popViewController(animated: true)
                }
                self.navigationController?.pushViewController(selector, animated: true)
            case let .failure(error):
                self.showProblem(error)
            }
        }
    }

    /// A deliberate message action, not a model-generated file command.
    /// Pasting/revising selected text happens manually inside the existing
    /// source-preserving draft editor. The formal Vault write gate is unchanged.
    func messageMenu(for turn: WCDBV3ChatMessage) -> UIMenu {
        var actions: [UIMenuElement] = [
            UIAction(title: V3L("复制消息"),
                     image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = turn.text
            }
        ]
        if turn.role == .assistant && turn.status == .completed {
            if sourceCardID != nil || noteDraftTarget != nil {
                actions.append(UIAction(
                    title: V3L("统一预览笔记与原卡修订"),
                    image: UIImage(systemName: "checklist")) { [weak self] _ in
                        self?.openDuplexReview(sourceMessageID: turn.messageID)
                    })
            }
            if sourceCardID != nil {
                actions.append(UIAction(
                    title: V3L("修订关联原卡"),
                    image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis")) {
                        [weak self] _ in self?.openReviewedOriginalCard()
                    })
            }
            if noteDraftTarget != nil {
                actions.append(UIAction(
                    title: V3L("在关联笔记草稿中整理"),
                    image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
                        self?.openAuthorizedNoteDraft()
                    })
                actions.append(UIAction(
                    title: V3L("生成关联笔记候选卡"),
                    image: UIImage(systemName: "square.stack.3d.up")) { [weak self] _ in
                        self?.openNoteCandidatePool()
                    })
            }
            if pendingDuplex != nil || !previousDuplex.isEmpty {
                actions.append(UIAction(
                    title: V3L("查看修订记录与逐项回执"),
                    image: UIImage(systemName: "doc.text.magnifyingglass")) {
                        [weak self] _ in self?.openDuplexReceipts()
                    })
            }
        }
        return UIMenu(children: actions)
    }

    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        guard history.indices.contains(indexPath.row) else { return nil }
        let message = history[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) {
            [weak self] _ in
            self?.messageMenu(for: message) ?? UIMenu(children: [])
        }
    }

    @objc private func openDuplexReceipts() {
        let recorded = (pendingDuplex.map { [$0] } ?? []) + previousDuplex
        guard !recorded.isEmpty else { return }
        let page = ImpressDuplexReceiptHistoryController(records: recorded)
        page.onSelect = { [weak self] record in
            self?.showDuplexReceipt(record)
        }
        page.onRefresh = { [weak self] in
            guard let self else { return [] }
            return (self.pendingDuplex.map { [$0] } ?? []) + self.previousDuplex
        }
        navigationController?.pushViewController(page, animated: true)
    }

    private func showDuplexReceipt(_ receipt: WCDBV3DuplexProposal) {
        let page = UIViewController()
        page.title = V3L("修订回执详情")
        page.view.backgroundColor = ImpressV3Appearance.page
        let text = UITextView()
        text.translatesAutoresizingMaskIntoConstraints = false
        text.isEditable = false
        text.isSelectable = true
        text.font = ImpressV3Appearance.Typography.body
        text.adjustsFontForContentSizeCategory = true
        text.textColor = ImpressV3Appearance.primaryText
        text.backgroundColor = ImpressV3Appearance.surface
        text.accessibilityIdentifier = "impress.duplex.receipt-detail"
        text.text = V3L("提案 ID：") + receipt.proposalID.uuidString +
            "\n\n" + V3L("笔记：") + (receipt.noteIdentity?.relativePath ??
                V3L("笔记未选择")) +
            "\nSHA-256: " + (receipt.noteBaseDigest ?? "-") +
            "\n" + V3L("状态：") + receipt.state.noteStatus.rawValue +
            "\n" + V3L("笔记回执：") + (receipt.noteReceipt ??
                V3L("尚无回执")) +
            "\n\n" + V3L("原卡：") + (receipt.cardID?.uuidString ??
                V3L("原卡未选择")) +
            "\nRevision: " + String(receipt.cardContentRevision ?? -1) +
            "\n" + V3L("状态：") + receipt.state.cardStatus.rawValue +
            "\n" + V3L("卡片回执：") + (receipt.cardReceipt ??
                V3L("尚无回执")) +
            "\n\n" + V3L("此页为历史回执，不自动重试或改写任何内容。")
        page.view.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.topAnchor),
            text.bottomAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.bottomAnchor),
            text.leadingAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.trailingAnchor)
        ])
        // Historical receipts are read-only unless their exact completed
        // proposal has a reversible target. Undo is a separate explicit
        // full-diff, CAS-protected operation, never a tap on old message text.
        if [.applied, .undoing].contains(receipt.state.noteStatus) ||
           [.applied, .undoing].contains(receipt.state.cardStatus) {
            let action = UIAction(title: V3L("安全撤销"),
                                  image: UIImage(systemName: "arrow.uturn.backward")) {
                [weak self] _ in
                guard let self, let repo = self.chatRepository else { return }
                self.showDuplexEditor(repository: repo, cardID: receipt.cardID,
                    contentRevision: nil, messageID: receipt.sourceMessageID,
                    recovering: receipt)
            }
            page.navigationItem.rightBarButtonItem = UIBarButtonItem(primaryAction: action)
        }
        navigationController?.pushViewController(page, animated: true)
    }

    @objc private func resumeDuplexReview() {
        openDuplexReview(sourceMessageID: pendingDuplex?.sourceMessageID)
    }

    private func openDuplexReview(sourceMessageID: UUID?) {
        guard !sending && !restoring, sourceIdentity != nil,
              let repo = chatRepository else { return }
        // Never replace an unfinished two-target operation with an unrelated
        // Chat suggestion: resume the recorded partial receipt first.
        if let p = pendingDuplex, !p.state.completed {
            showDuplexEditor(repository: repo, cardID: p.cardID,
                contentRevision: nil, messageID: p.sourceMessageID, recovering: p)
            return
        }
        if sourceCardID == nil, let identity = noteDraftTarget {
            // Reverse direction: a note may have several original cards. User
            // chooses by stable cardID instead of guessing from the title.
            Task { [weak self] in
                guard let self else { return }
                do {
                    let cards = try await repo.listRelatedCards(for: identity, limit: 20)
                    let picker = UIAlertController(title: V3L("选择关联原卡"),
                        message: V3L("可仅修改笔记，或选择一张已关联的原卡共同预览。"),
                        preferredStyle: .actionSheet)
                    picker.addAction(UIAlertAction(title: V3L("仅修改笔记"),
                        style: .default) { [weak self] _ in
                        self?.showDuplexEditor(repository: repo, cardID: nil,
                            contentRevision: nil, messageID: sourceMessageID, recovering: nil)
                    })
                    for card in cards {
                        picker.addAction(UIAlertAction(
                            title: String(card.question.prefix(48)),
                            style: .default) { [weak self] _ in
                            self?.showDuplexEditor(repository: repo, cardID: card.cardID,
                                contentRevision: nil, messageID: sourceMessageID, recovering: nil)
                        })
                    }
                    picker.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
                    picker.popoverPresentationController?.sourceView = self.view
                    picker.popoverPresentationController?.sourceRect = CGRect(
                        x: self.view.bounds.midX, y: self.view.bounds.midY,
                        width: 1, height: 1)
                    self.present(picker, animated: true)
                } catch { self.showProblem(error) }
            }
            return
        }
        showDuplexEditor(repository: repo, cardID: sourceCardID,
            contentRevision: sourceContentRevision, messageID: sourceMessageID,
            recovering: nil)
    }

    private func showDuplexEditor(repository: ReviewWCDBRepository, cardID: UUID?,
                                  contentRevision: Int?, messageID: UUID?,
                                  recovering: WCDBV3DuplexProposal?) {
        let editor = ImpressDuplexChangeController(
            repository: repository, cardID: cardID,
            sourceContentRevision: contentRevision,
            noteIdentity: recovering?.noteIdentity ?? noteDraftTarget,
            sourceMessageID: messageID, pending: recovering) { [weak self] changed in
                guard let self else { return false }
                await self.saveChain?.value
                if let index = self.previousDuplex.firstIndex(where: {
                    $0.proposalID == changed.proposalID
                }) {
                    // Undo an archived proposal IN PLACE; do not replace the
                    // newer active proposal or erase unrelated receipts.
                    let oldArchived = self.previousDuplex[index]
                    self.previousDuplex[index] = changed
                    let success = await self.persistLocal()
                    if !success { self.previousDuplex[index] = oldArchived }
                    return success
                }
                let original = self.pendingDuplex
                let archived = self.previousDuplex
                if let original, original.proposalID != changed.proposalID {
                    // Do not silently discard old receipts. If the WCDB
                    // record reaches its protective size cap, fail closed and
                    // keep the prior durable proposal instead.
                    guard original.state.completed else { return false }
                    self.previousDuplex.insert(original, at: 0)
                }
                self.pendingDuplex = changed
                let ok = await self.persistLocal()
                if !ok {
                    self.pendingDuplex = original
                    self.previousDuplex = archived
                }
                if ok { self.refreshModelPicker() }
                return ok
            }
        navigationController?.pushViewController(editor, animated: true)
    }

    /// These actions reuse the existing authoritative editor and WCDB CAS.
    /// AI message text is advice, never executable instructions or an implicit
    /// replacement answer. The user manually reviews and saves the ORIGINAL ID.
    private func openReviewedOriginalCard() {
        guard !sending && !restoring, let cardID = sourceCardID,
              let expected = sourceContentRevision else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let repo = try self.chatRepository ?? self.injectedRepository ??
                    ImpressV3ReviewEnvironment.repository()
                guard let card = try await repo.content(for: cardID) else {
                    throw ReviewWCDBError.missingCard
                }
                guard card.contentRevision == expected else {
                    throw ChatFlowError.sourceChanged
                }
                guard let queueItem = try await repo.fetchQueueCandidates().first(where: {
                    $0.cardID == cardID
                }) else { throw ReviewWCDBError.missingCard }
                let correct = Set((card.correctIndices ?? "").split(separator: ",")
                    .compactMap { Int($0) })
                let choices: [ImpressV3CardDraft.Choice] =
                    (card.choices ?? "").isEmpty
                    ? [.init(), .init()]
                    : (card.choices ?? "").components(separatedBy: "\n")
                        .enumerated().map { index, text in
                            .init(text: text, isCorrect: correct.contains(index))
                        }
                let draft = ImpressV3CardDraft(
                    kind: CardType(rawValue: card.cardType) ?? .standard,
                    question: card.question, answer: card.answerText ?? "",
                    choices: choices, allowsMultipleCorrect: correct.count > 1,
                    imageData: card.imageData, sourceNotePath: card.sourceNotePath)
                let editor = ImpressV3CardComposerViewController(
                    draft: draft, editingCardID: cardID)
                editor.onSave = { [weak self] updated in
                    try await repo.updateManagedCard(updated,
                        expectedRevision: queueItem.revision,
                        expectedContentRevision: card.contentRevision,
                        origin: .approvedAI)
                    self?.privacyLabel.text = V3L(
                        "原卡已按确认内容保存；继续讨论前请重新打开以读取新版本。")
                    // The Chat source version is immutable for this controller:
                    // a subsequent Send fails closed rather than reusing stale context.
                }
                let nav = ImNavigationViewController(rootViewController: editor)
                nav.modalPresentationStyle = .pageSheet
                nav.sheetPresentationController?.detents = [.large()]
                self.present(nav, animated: true)
            } catch { self.showProblem(error) }
        }
    }

    /// Reuse the existing confirmed question-pool flow; no implicit model call,
    /// no new duplicate-card path, and no automatic upload of the linked note.
    private func openNoteCandidatePool() {
        guard !sending && !restoring, let identity = noteDraftTarget else { return }
        guard ImVaultReadOnlyProbe.shared.authorizedVaultID == identity.vaultID else {
            showProblem(ImVaultSyncFailure.wrongVault)
            return
        }
        ImVaultReadSync.shared.read(identity) { [weak self] result in
            guard let self,
                  ImVaultReadOnlyProbe.shared.authorizedVaultID == identity.vaultID
            else { return }
            switch result {
            case .success(let document):
                guard document.identity == identity else {
                    self.showProblem(ImVaultSyncFailure.wrongVault)
                    return
                }
                self.navigationController?.pushViewController(
                    ImpressAIQuestionGenerationViewController(document: document),
                    animated: true)
            case .failure(let error): self.showProblem(error)
            }
        }
    }

    private func openAuthorizedNoteDraft() {
        guard !sending && !restoring, let identity = noteDraftTarget else { return }
        guard ImVaultReadOnlyProbe.shared.authorizedVaultID == identity.vaultID else {
            showProblem(ImVaultSyncFailure.wrongVault)
            return
        }
        ImVaultReadSync.shared.read(identity) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let live):
                do {
                    let draft: ImVaultDraft
                    if let existing = try ImVaultPrivateStore.loadDraft(identity: identity) {
                        // Retain an older unsent draft even when Obsidian changed.
                        // The existing Diff path detects a stale source and
                        // refuses the write rather than silently discarding it.
                        draft = existing
                    } else {
                        draft = try ImVaultDraft(identity: identity,
                            baseText: live.markdown, baseRawData: live.sourceBytes)
                    }
                    self.navigationController?.pushViewController(
                        ImVaultDraftEditorController(draft: draft), animated: true)
                } catch { self.showProblem(error) }
            case .failure(let error):
                self.showProblem(error)
            }
        }
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
                self.contextChoiceMade = true
                self.contextConsentGranted = false
                self.includeCardContext = false
                self.contextReferences = []
                self.performSend(text, route: route)
            })
            confirm.addAction(UIAlertAction(title: noteIdentity == nil
                ? V3L("附带当前卡片") : V3L("附带本次笔记材料"),
                                            style: .default) { [weak self] _ in
                guard let self else { return }
                if let key = self.sourceIdentity {
                    if self.noteIdentity != nil && self.sourceAnswer == nil &&
                       self.contextReferences.isEmpty {
                        self.openNoteSectionPicker()
                        return // Keep draft; choose sections without sending.
                    }
                    if !self.contextReferences.allSatisfy({
                        $0.stableIdentity == key &&
                        $0.sourceRevision == self.currentSourceVersion
                    }) {
                        self.contextReferences = []
                        self.contextConsentGranted = false
                        self.openNoteSectionPicker()
                        return
                    }
                    if self.contextReferences.isEmpty {
                        let excerpt = self.noteIdentity == nil
                            ? question + "\n" + (self.sourceAnswer ?? "")
                            : (self.sourceAnswer ?? "")
                        self.contextReferences = [WCDBV3ChatContextReference(
                            stableIdentity: key,
                            sourceRevision: self.currentSourceVersion, excerpt: excerpt)]
                    }
                }
                self.contextChoiceMade = true
                self.contextConsentGranted = true
                self.includeCardContext = true
                self.performSend(text, route: route)
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
            if noteIdentity != nil {
                system += "\n" + V3L("当前笔记来源：") + question
                for reference in contextReferences {
                    system += "\n" + V3L("本次明确批准的章节或摘录：") + reference.excerpt
                }
            } else {
                system += "\n" + V3L("当前卡片的问题：") + question
                if let answer = sourceAnswer, !answer.isEmpty {
                    system += "\n" + V3L("当前卡片的参考答案：") + answer
                }
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
        pendingDuplex = session.pendingDuplex
        previousDuplex = session.duplexHistory ?? []
        sessionPromptOverride = session.promptOverride
        history = session.messages
        for i in history.indices where history[i].status == .pending {
            history[i].status = .failed // No auto-replay after interruption.
        }
        messageInput.text = session.inputDraft
        contextReferences = session.contextReferences
        requestFailure = session.requestError
        contextConsentGranted = session.contextConsentGranted == true
        let approved = contextReferences.first(where: { $0.stableIdentity == sourceIdentity })
        let stillCurrent = approved?.sourceRevision == currentSourceVersion
        includeCardContext = contextConsentGranted && approved != nil && stillCurrent
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
           base.promptOverride == sessionPromptOverride &&
           base.pendingDuplex == pendingDuplex &&
           (base.duplexHistory ?? []) == previousDuplex &&
           (base.contextConsentGranted == true) == contextConsentGranted { return true }
        var next = base
        next.messages = history
        next.inputDraft = messageInput.text ?? ""
        next.contextReferences = contextReferences
        next.requestError = requestFailure
        next.promptOverride = sessionPromptOverride
        next.pendingDuplex = pendingDuplex
        next.duplexHistory = previousDuplex
        next.contextConsentGranted = contextConsentGranted
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

@MainActor
final class ImpressChatNoteSectionPicker: UITableViewController {
    private let sections: [ImpressAISectionItem]
    private var selected: Set<String> = []
    var onApply: (([ImpressAISectionItem]) -> Void)?

    init(sections: [ImpressAISectionItem]) {
        self.sections = sections
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("选择笔记章节")
        tableView.backgroundColor = ImpressV3Appearance.page
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: V3L("使用所选"), style: .done,
            target: self, action: #selector(acceptSelection))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier =
            "impress.ai.chat.section-confirm"
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int { sections.count }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "chat.section")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "chat.section")
        var config = UIListContentConfiguration.subtitleCell()
        config.text = item.heading
        config.secondaryText = String(item.text.utf8.count) + " bytes"
        config.textProperties.numberOfLines = 2
        cell.contentConfiguration = config
        cell.accessoryType = selected.contains(item.id) ? .checkmark : .none
        cell.backgroundColor = ImpressV3Appearance.surface
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = sections[indexPath.row].id
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        tableView.reloadRows(at: [indexPath], with: .none)
        let size = sections.filter { selected.contains($0.id) }
            .reduce(0) { $0 + $1.text.utf8.count }
        navigationItem.rightBarButtonItem?.isEnabled = !selected.isEmpty && size <= 8_000
    }

    @objc private func acceptSelection() {
        let selection = sections.filter { selected.contains($0.id) }
        let size = selection.reduce(0) { $0 + $1.text.utf8.count }
        guard !selection.isEmpty, size <= 8_000 else { return }
        onApply?(selection)
    }
}



@MainActor
final class ImpressDuplexReceiptHistoryController: UITableViewController {
    private var records: [WCDBV3DuplexProposal]
    var onSelect: ((WCDBV3DuplexProposal) -> Void)?
    var onRefresh: (() -> [WCDBV3DuplexProposal])?

    init(records: [WCDBV3DuplexProposal]) {
        self.records = records
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("修订回执历史")
        tableView.accessibilityIdentifier = "impress.duplex.receipt-history"
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let onRefresh { records = onRefresh() }
        tableView.reloadData()
    }
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        records.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "duplex.receipt")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "duplex.receipt")
        let entry = records[indexPath.row]
        cell.textLabel?.text = entry.noteIdentity?.relativePath ??
            (entry.cardID?.uuidString ?? entry.proposalID.uuidString)
        cell.detailTextLabel?.text = V3L("笔记：") + entry.state.noteStatus.rawValue +
            " · " + V3L("原卡：") + entry.state.cardStatus.rawValue
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(records[indexPath.row])
    }
}

// MARK: - Explicit, recoverable note + ORIGINAL card change review
//
// This deliberately uses the existing private Vault draft, authorized scoped
// file writer, WCDB card CAS, and Chat session record. The AI response is only
// discussion; there is no model-to-file command and NO implicit production write.
@MainActor
final class ImpressDuplexChangeController: UIViewController {
    typealias SaveProposal = @MainActor (WCDBV3DuplexProposal) async -> Bool
    private let repository: ReviewWCDBRepository
    private let cardID: UUID?
    private let sourceContentRevision: Int?
    private let noteIdentity: ImVaultFileIdentity?
    private let sourceMessageID: UUID?
    private let saveProposal: SaveProposal
    private var pending: WCDBV3DuplexProposal?
    private var card: WCDBV3CardContent?
    private var reviewRevision: Int?
    private var draft: ImVaultDraft?
    private var loaded = false

    private let cardInfo = UILabel()
    private let noteInfo = UILabel()
    private let questionInput = UITextView()
    private let answerInput = UITextView()
    private let editNoteButton = UIButton(type: .system)
    private let previewButton = UIButton(type: .system)

    init(repository: ReviewWCDBRepository, cardID: UUID?,
         sourceContentRevision: Int?, noteIdentity: ImVaultFileIdentity?,
         sourceMessageID: UUID?, pending: WCDBV3DuplexProposal?,
         saveProposal: @escaping SaveProposal) {
        self.repository = repository
        self.cardID = cardID
        self.sourceContentRevision = sourceContentRevision
        self.noteIdentity = noteIdentity
        self.sourceMessageID = sourceMessageID
        self.pending = pending
        self.saveProposal = saveProposal
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    private func label(_ content: String) -> UILabel {
        let label = UILabel()
        label.text = content
        label.font = ImpressV3Appearance.Typography.body
        label.adjustsFontForContentSizeCategory = true
        label.textColor = ImpressV3Appearance.primaryText
        label.numberOfLines = 0
        return label
    }
    private func configure(_ view: UITextView, identifier: String, height: CGFloat) {
        view.font = ImpressV3Appearance.Typography.body
        view.adjustsFontForContentSizeCategory = true
        view.textColor = ImpressV3Appearance.primaryText
        view.backgroundColor = ImpressV3Appearance.surface
        view.layer.cornerRadius = ImpressV3Appearance.Radius.field
        view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        view.accessibilityIdentifier = identifier
        ImpressSpeechAccessory.install(on: view)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("笔记与原卡修订")
        view.backgroundColor = ImpressV3Appearance.page
        navigationItem.largeTitleDisplayMode = .never
        let scroll = UIScrollView()
        let stack = UIStackView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = ImpressV3Appearance.Metrics.rowSpacing
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16,
                                                                  bottom: 24, trailing: 16)
        cardInfo.font = ImpressV3Appearance.Typography.footnote
        noteInfo.font = ImpressV3Appearance.Typography.footnote
        for info in [cardInfo, noteInfo] {
            info.adjustsFontForContentSizeCategory = true
            info.numberOfLines = 0
            info.textColor = ImpressV3Appearance.secondaryText
        }
        configure(questionInput, identifier: "impress.duplex.question", height: 114)
        configure(answerInput, identifier: "impress.duplex.answer", height: 160)
        ImpressV3Appearance.styleQuietButton(editNoteButton,
            title: V3L("修改对应笔记的私有草稿"), symbol: "square.and.pencil")
        editNoteButton.addTarget(self, action: #selector(editNote), for: .touchUpInside)
        editNoteButton.accessibilityIdentifier = "impress.duplex.edit-note"
        ImpressV3Appearance.styleQuietButton(previewButton,
            title: V3L("预览两个对象的完整修改"), symbol: "checkmark.shield")
        previewButton.addTarget(self, action: #selector(preparePreview), for: .touchUpInside)
        previewButton.accessibilityIdentifier = "impress.duplex.preview"
        previewButton.isEnabled = false
        stack.addArrangedSubview(label(V3L("原卡 · 编辑题目与答案")))
        stack.addArrangedSubview(cardInfo)
        stack.addArrangedSubview(label(V3L("题目")))
        stack.addArrangedSubview(questionInput)
        stack.addArrangedSubview(label(V3L("答案")))
        stack.addArrangedSubview(answerInput)
        stack.addArrangedSubview(label(V3L("关联笔记 · 局部改动")))
        stack.addArrangedSubview(noteInfo)
        stack.addArrangedSubview(editNoteButton)
        stack.addArrangedSubview(previewButton)
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        Task { await loadTargets() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if loaded { refreshDraft() }
    }

    private func loadTargets() async {
        do {
            if let cardID {
                guard let item = try await repository.content(for: cardID),
                      let queue = try await repository.fetchQueueCandidates()
                        .first(where: { $0.cardID == cardID }) else {
                    throw ReviewWCDBError.missingCard
                }
                if pending == nil, let expected = sourceContentRevision,
                   item.contentRevision != expected {
                    throw ReviewWCDBError.contentConflict
                }
                // A card+note proposal may only target the card's exact
                // verified Vault identity, never a same-title note.
                if let identity = noteIdentity {
                    guard let encoded = item.sourceNotePath,
                          (try? ImpressBatchSourceKey.decode(encoded)) == identity else {
                        throw ImVaultSyncFailure.wrongVault
                    }
                }
                card = item
                reviewRevision = queue.revision
                let canEditStandard = item.cardType == 0
                questionInput.isEditable = canEditStandard && pending == nil
                answerInput.isEditable = canEditStandard && pending == nil
                questionInput.text = pending?.cardEditedQuestion ?? item.question
                answerInput.text = pending?.cardEditedAnswer ?? item.answerText ?? ""
                cardInfo.text = "cardID: " + cardID.uuidString +
                    "\nContent revision: " + String(item.contentRevision) +
                    (canEditStandard ? "" :
                        "\n" + V3L("非普通卡片请在原卡编辑器修改；本次可仅确认笔记。"))
            } else {
                cardInfo.text = V3L("没有关联原卡，本次仅核查笔记修改。")
                questionInput.isHidden = true
                answerInput.isHidden = true
            }
            if noteIdentity == nil {
                editNoteButton.isHidden = true
                noteInfo.text = V3L("没有可核实的来源笔记，仅修改原卡。")
            }
            if pending != nil {
                editNoteButton.isEnabled = false
                navigationItem.prompt = V3L("恢复待处理提案；不会自动重放任何写入。")
            }
            loaded = true
            previewButton.isEnabled = true
            refreshDraft()
        } catch { presentIssue(V3L("读取原卡或来源失败"), error.localizedDescription) }
    }

    private func refreshDraft() {
        guard let identity = noteIdentity else { return }
        do {
            guard ImVaultReadOnlyProbe.shared.authorizedVaultID == identity.vaultID else {
                throw ImVaultSyncFailure.wrongVault
            }
            draft = try ImVaultPrivateStore.loadDraft(identity: identity)
            if let draft {
                let diff = ImVaultDiff.summary(base: draft.baseText,
                    edited: draft.editedText, maximumLines: 200)
                noteInfo.text = V3L("目标：") + identity.relativePath +
                    "\nSHA-256: " + draft.baseDigest +
                    "\n" + (draft.hasChanges
                        ? (diff.complete ? V3L("已有局部修订草稿，可预览与选择写回。") :
                           V3L("修改范围超过预览上限，禁止确认笔记写回。"))
                        : V3L("草稿未修改；可只更新原卡。"))
            } else {
                noteInfo.text = V3L("目标：") + identity.relativePath +
                    "\n" + V3L("尚无笔记修订草稿；打开编辑器增量修改原文。")
            }
        } catch {
            draft = nil
            noteInfo.text = V3L("无法读取笔记草稿：") + error.localizedDescription
        }
    }

    @objc private func editNote() {
        guard pending == nil, let identity = noteIdentity,
              ImVaultReadOnlyProbe.shared.authorizedVaultID == identity.vaultID else {
            presentIssue(V3L("来源身份已失效"), ImVaultSyncFailure.wrongVault.localizedDescription)
            return
        }
        ImVaultReadSync.shared.read(identity) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let source):
                do {
                    let edit = try ImVaultPrivateStore.loadDraft(identity: identity)
                        ?? ImVaultDraft(identity: identity, baseText: source.markdown,
                                        baseRawData: source.sourceBytes)
                    self.navigationController?.pushViewController(
                        ImVaultDraftEditorController(draft: edit), animated: true)
                } catch { self.presentIssue(V3L("笔记草稿不可用"), error.localizedDescription) }
            case .failure(let error):
                self.presentIssue(V3L("源笔记读取失败"), error.localizedDescription)
            }
        }
    }

    @objc private func preparePreview() {
        guard loaded else { return }
        Task { [weak self] in
            guard let self else { return }
            if let pending = self.pending {
                self.openApproval(pending)
                return
            }
            let revisedQ = self.questionInput.text.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let revisedA = self.answerInput.text ?? ""
            let changedCard = self.card?.cardType == 0 &&
                (self.card?.question != revisedQ || self.card?.answerText != revisedA)
            let changedNote = self.draft?.hasChanges == true
            guard changedCard || changedNote else {
                self.presentIssue(V3L("内容未变化"), V3L("请先编辑笔记草稿或原卡。"))
                return
            }
            guard !changedCard || (!revisedQ.isEmpty && revisedQ.utf8.count <= 10_000 &&
                                  revisedA.utf8.count <= 40_000) else {
                self.presentIssue(V3L("卡片内容无效"), V3L("题目不能为空或超过安全长度。"))
                return
            }
            if changedNote, let d = self.draft {
                guard ImVaultDiff.summary(base: d.baseText, edited: d.editedText,
                                          maximumLines: 200).complete else {
                    self.presentIssue(V3L("修改预览过长"),
                        V3L("请把笔记修改缩小到可完整核对的范围。"))
                    return
                }
            }
            let p = WCDBV3DuplexProposal(sourceMessageID: self.sourceMessageID,
                noteIdentity: changedNote ? self.noteIdentity : nil,
                noteBaseDigest: changedNote ? self.draft?.baseDigest : nil,
                noteEditedDigest: changedNote ? self.draft.map {
                    ImVaultDigest.sha256($0.proposedBytes)
                } : nil,
                cardID: changedCard ? self.cardID : nil,
                cardReviewRevision: changedCard ? self.reviewRevision : nil,
                cardContentRevision: changedCard ? self.card?.contentRevision : nil,
                cardBaseQuestion: changedCard ? self.card?.question : nil,
                cardBaseAnswer: changedCard ? self.card?.answerText : nil,
                cardEditedQuestion: changedCard ? revisedQ : nil,
                cardEditedAnswer: changedCard ? revisedA : nil,
                state: ImDuplexApprovalState(noteSelected: changedNote,
                                             cardSelected: changedCard))
            guard await self.saveProposal(p) else {
                self.presentIssue(V3L("提案未保存"),
                    V3L("Chat 的原子版本检查失败；修改尚未得到保存确认，禁止执行。"))
                return
            }
            self.pending = p
            self.openApproval(p)
        }
    }

    private func openApproval(_ proposal: WCDBV3DuplexProposal) {
        let page = ImpressDuplexApprovalController(
            repository: repository, proposal: proposal) { [weak self] changed in
                guard let self else { return false }
                let saved = await self.saveProposal(changed)
                if saved { self.pending = changed }
                return saved
            }
        navigationController?.pushViewController(page, animated: true)
    }

    private func presentIssue(_ title: String, _ detail: String) {
        let alert = UIAlertController(title: title, message: detail, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        if presentedViewController == nil { present(alert, animated: true) }
    }
}

/// Only local, verified bytes form a reverse note edit. Reconstructing
/// Markdown from rendered rich text or from an AI transcript is forbidden.
@MainActor
enum ImpressDuplexUndoGate {
    static func inverseDraft(_ existing: ImVaultDraft,
                             expectedBaseDigest: String?,
                             expectedAppliedDigest: String?) throws -> ImVaultDraft {
        try existing.validate()
        guard existing.baseDigest == expectedBaseDigest,
              ImVaultDigest.sha256(existing.proposedBytes) == expectedAppliedDigest,
              let appliedText = String(data: existing.proposedBytes, encoding: .utf8) else {
            throw ImVaultSyncFailure.conflict
        }
        let reversed = try ImVaultDraft(identity: existing.identity,
            baseText: appliedText, baseRawData: existing.proposedBytes,
            editedText: existing.baseText)
        try reversed.validate()
        guard reversed.proposedBytes == existing.baseRawData,
              reversed.hasChanges else {
            throw ImVaultSyncFailure.verificationFailed
        }
        return reversed
    }
}

@MainActor
final class ImpressDuplexUndoReviewController: UIViewController {
    typealias UndoAction = @MainActor () async -> Result<String, Error>
    private let content: String
    private let onConfirm: UndoAction
    private let button = UIButton(type: .system)
    private var applying = false

    init(content: String, onConfirm: @escaping UndoAction) {
        self.content = content
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("核对撤销内容")
        view.backgroundColor = ImpressV3Appearance.page
        let body = UITextView()
        body.translatesAutoresizingMaskIntoConstraints = false
        body.text = content
        body.font = ImpressV3Appearance.Typography.compactCode
        body.adjustsFontForContentSizeCategory = true
        body.textColor = ImpressV3Appearance.primaryText
        body.backgroundColor = ImpressV3Appearance.surface
        body.isEditable = false
        body.isSelectable = true
        body.accessibilityIdentifier = "impress.duplex.undo.full-diff"
        ImpressV3Appearance.styleQuietButton(button,
            title: V3L("确认按当前版本撤销"), symbol: "arrow.uturn.backward")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "impress.duplex.undo.confirm"
        button.addTarget(self, action: #selector(askUndo), for: .touchUpInside)
        view.addSubview(body)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            body.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                                          constant: 12),
            body.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                                           constant: -12),
            body.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -10),
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                                             constant: 16),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                                              constant: -16),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                           constant: -8),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    @objc private func askUndo() {
        guard !applying else { return }
        let alert = UIAlertController(title: V3L("确认撤销这个目标？"),
            message: V3L("撤销也会重新验证当前内容版本；若别人已合法修改，必须停止。不会删除 FSRS 历史或自动重放。"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: V3L("确认撤销"), style: .destructive) {
            [weak self] _ in
            guard let self else { return }
            self.applying = true
            self.button.isEnabled = false
            Task {
                let result = await self.onConfirm()
                self.applying = false
                if case .failure = result { self.button.isEnabled = true }
                let succeeded: Bool
                let message: String
                switch result {
                case .success(let detail):
                    succeeded = true
                    message = detail
                case .failure(let error):
                    succeeded = false
                    message = error.localizedDescription
                }
                let response = UIAlertController(
                    title: succeeded ? V3L("撤销结果已保存") : V3L("撤销未完成"),
                    message: message, preferredStyle: .alert)
                response.addAction(UIAlertAction(title: V3L("确定"), style: .default) {
                    [weak self] _ in
                    if succeeded {
                        self?.navigationController?.popViewController(animated: true)
                    }
                })
                self.present(response, animated: true)
            }
        })
        present(alert, animated: true)
    }
}

@MainActor
final class ImpressDuplexApprovalController: UIViewController {
    private let repository: ReviewWCDBRepository
    private let saveProposal: @MainActor (WCDBV3DuplexProposal) async -> Bool
    private var proposal: WCDBV3DuplexProposal
    private let noteToggle = UISwitch()
    private let cardToggle = UISwitch()
    private let preview = UITextView()
    private let confirm = UIButton(type: .system)
    private var undoBarItem: UIBarButtonItem?
    private var notePreviewValid = false
    private var committing = false

    init(repository: ReviewWCDBRepository, proposal: WCDBV3DuplexProposal,
         saveProposal: @escaping @MainActor (WCDBV3DuplexProposal) async -> Bool) {
        self.repository = repository
        self.proposal = proposal
        self.saveProposal = saveProposal
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("逐项核对并确认修改")
        view.backgroundColor = ImpressV3Appearance.page
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.isEditable = false
        preview.isSelectable = true
        preview.backgroundColor = ImpressV3Appearance.surface
        preview.textColor = ImpressV3Appearance.primaryText
        preview.font = ImpressV3Appearance.Typography.compactCode
        preview.adjustsFontForContentSizeCategory = true
        preview.accessibilityIdentifier = "impress.duplex.full-diff"
        preview.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 22, right: 12)

        let controls = UIStackView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .vertical
        controls.spacing = 6
        controls.addArrangedSubview(makeToggleRow(V3L("修改原笔记"), noteToggle))
        controls.addArrangedSubview(makeToggleRow(V3L("修改原卡"), cardToggle))
        noteToggle.accessibilityIdentifier = "impress.duplex.select-note"
        cardToggle.accessibilityIdentifier = "impress.duplex.select-card"
        noteToggle.isOn = proposal.state.noteSelected
        cardToggle.isOn = proposal.state.cardSelected
        noteToggle.addTarget(self, action: #selector(updateConfirmation), for: .valueChanged)
        cardToggle.addTarget(self, action: #selector(updateConfirmation), for: .valueChanged)
        noteToggle.isEnabled = proposal.noteIdentity != nil &&
            ![.applied, .undoing, .reverted].contains(proposal.state.noteStatus)
        cardToggle.isEnabled = proposal.cardID != nil &&
            ![.applied, .undoing, .reverted].contains(proposal.state.cardStatus)

        ImpressV3Appearance.styleQuietButton(confirm,
            title: V3L("确认执行所选修改"), symbol: "checkmark.shield")
        confirm.addTarget(self, action: #selector(confirmChanges), for: .touchUpInside)
        confirm.accessibilityIdentifier = "impress.duplex.confirm"
        confirm.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(preview)
        view.addSubview(controls)
        view.addSubview(confirm)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            preview.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            preview.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            preview.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -8),
            controls.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            controls.bottomAnchor.constraint(equalTo: confirm.topAnchor, constant: -8),
            confirm.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            confirm.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            confirm.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            confirm.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
        let discard = UIBarButtonItem(
            title: V3L("放弃未完成项"), style: .plain,
            target: self, action: #selector(discardUnapplied))
        let inverse = UIBarButtonItem(
            title: V3L("安全撤销"), style: .plain,
            target: self, action: #selector(openUndoOptions))
        undoBarItem = inverse
        navigationItem.rightBarButtonItems = [discard, inverse]
        refreshPreview()
    }

    @objc private func discardUnapplied() {
        guard !committing else { return }
        let confirmDiscard = UIAlertController(title: V3L("放弃未完成项？"),
            message: V3L("仅取消尚未执行的目标，已成功的笔记和原卡保留且不会撤销。"),
            preferredStyle: .alert)
        confirmDiscard.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        confirmDiscard.addAction(UIAlertAction(title: V3L("确认放弃"), style: .destructive) {
            [weak self] _ in
            guard let self else { return }
            Task {
                var cancelled = self.proposal
                if cancelled.state.noteStatus != .applied {
                    cancelled.state.noteSelected = false
                }
                if cancelled.state.cardStatus != .applied {
                    cancelled.state.cardSelected = false
                }
                guard await self.saveProposal(cancelled) else {
                    self.showResult(V3L("无法保存取消决定"),
                        V3L("原待处理项仍然保留，不执行任何写回。"))
                    return
                }
                self.proposal = cancelled
                self.navigationController?.popViewController(animated: true)
            }
        })
        present(confirmDiscard, animated: true)
    }

    private func makeToggleRow(_ name: String, _ control: UISwitch) -> UIView {
        let label = UILabel()
        label.text = name
        label.font = ImpressV3Appearance.Typography.body
        label.adjustsFontForContentSizeCategory = true
        label.textColor = ImpressV3Appearance.primaryText
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return row
    }

    private func refreshPreview() {
        var pieces = [V3L("文件与数据库不是同一个事务；按对象保留回执、冲突与重试。"),
                      V3L("必须逐项核对下方完整差异；无确认不会写入。")]
        if let identity = proposal.noteIdentity {
            pieces.append("\n" + V3L("笔记：") + identity.relativePath +
                          "\nSHA-256: " + (proposal.noteBaseDigest ?? "?") +
                          "\n" + V3L("状态：") + proposal.state.noteStatus.rawValue)
            do {
                guard let draft = try ImVaultPrivateStore.loadDraft(identity: identity),
                      draft.baseDigest == proposal.noteBaseDigest,
                      ImVaultDigest.sha256(draft.proposedBytes) ==
                          proposal.noteEditedDigest else {
                    throw ImVaultSyncFailure.conflict
                }
                let diff = ImVaultDiff.summary(base: draft.baseText,
                    edited: draft.editedText, maximumLines: 200)
                notePreviewValid = diff.complete
                pieces.append(diff.text)
            } catch {
                notePreviewValid = false
                pieces.append(V3L("草稿变更或不存在：旧批准已失效，不能写入。") +
                              "\n" + error.localizedDescription)
            }
        }
        if let id = proposal.cardID {
            pieces.append("\ncardID: " + id.uuidString +
                          "\nContent revision: " + String(proposal.cardContentRevision ?? -1) +
                          "\n" + V3L("状态：") + proposal.state.cardStatus.rawValue)
            pieces.append("\n" + V3L("原题目：") + "\n" + (proposal.cardBaseQuestion ?? "") +
                          "\n" + V3L("新题目：") + "\n" + (proposal.cardEditedQuestion ?? "") +
                          "\n" + V3L("原答案：") + "\n" + (proposal.cardBaseAnswer ?? "") +
                          "\n" + V3L("新答案：") + "\n" + (proposal.cardEditedAnswer ?? ""))
        }
        if let receipt = proposal.noteReceipt {
            pieces.append("\n" + V3L("笔记回执：") + receipt)
        }
        if let receipt = proposal.cardReceipt {
            pieces.append("\n" + V3L("卡片回执：") + receipt)
        }
        preview.text = pieces.joined(separator: "\n")
        noteToggle.isEnabled = proposal.noteIdentity != nil &&
            ![.applied, .undoing, .reverted].contains(proposal.state.noteStatus)
        cardToggle.isEnabled = proposal.cardID != nil &&
            ![.applied, .undoing, .reverted].contains(proposal.state.cardStatus)
        undoBarItem?.isEnabled = !committing && (
            [.applied, .undoing].contains(proposal.state.noteStatus) ||
            [.applied, .undoing].contains(proposal.state.cardStatus))
        updateConfirmation()
    }

    @objc private func updateConfirmation() {
        confirm.isEnabled = !committing &&
            !proposal.state.needsNoteUndo && !proposal.state.needsCardUndo &&
            ((noteToggle.isOn && noteToggle.isEnabled && notePreviewValid) ||
             (cardToggle.isOn && cardToggle.isEnabled))
    }

    @objc private func confirmChanges() {
        guard !committing else { return }
        let noteChosen = (noteToggle.isOn && notePreviewValid) ||
            (proposal.state.noteSelected && proposal.state.noteStatus == .applied)
        let cardChosen = cardToggle.isOn ||
            (proposal.state.cardSelected && proposal.state.cardStatus == .applied)
        guard noteChosen || cardChosen else { return }
        // The two selection bits belong to this exact saved proposal, not a
        // mutable UI draft. A new material revision needs a NEW proposal.
        var selected = proposal
        selected.state.noteSelected = noteChosen
        selected.state.cardSelected = cardChosen
        let targets = [
            noteChosen ? (V3L("笔记：") + (selected.noteIdentity?.relativePath ?? "")) : nil,
            cardChosen ? (V3L("原卡：") + (selected.cardID?.uuidString ?? "")) : nil
        ].compactMap { $0 }.joined(separator: "\n")
        let consent = UIAlertController(title: V3L("确认这两个目标的所选修改？"),
            message: targets + "\n\n" +
                V3L("来源冲突时停止覆盖；可能部分成功。正式 Vault 写入仍锁定，只有独立 Debug QA 副本获授权后能实际修改文件。"),
            preferredStyle: .alert)
        consent.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        consent.addAction(UIAlertAction(title: V3L("确认执行"), style: .destructive) {
            [weak self] _ in
            guard let self else { return }
            Task { await self.execute(selected) }
        })
        present(consent, animated: true)
    }

    private func execute(_ chosen: WCDBV3DuplexProposal) async {
        committing = true
        updateConfirmation()
        defer { committing = false; refreshPreview() }
        guard await saveProposal(chosen) else {
            showResult(V3L("回执无法保存"), V3L("未执行任何修改。"))
            return
        }
        proposal = chosen
        if proposal.state.needsNoteAction {
            // Intent recorded before the first side effect. On restart this
            // remains pending and is NEVER auto-replayed.
            proposal.state.noteStatus = .applying
            guard await saveProposal(proposal) else {
                showResult(V3L("笔记状态无法保存"), V3L("未执行文件写入。"))
                return
            }
            do {
                guard let id = proposal.noteIdentity,
                      let draft = try ImVaultPrivateStore.loadDraft(identity: id),
                      draft.baseDigest == proposal.noteBaseDigest,
                      ImVaultDigest.sha256(draft.proposedBytes) ==
                          proposal.noteEditedDigest,
                      ImVaultDiff.summary(base: draft.baseText, edited: draft.editedText,
                                          maximumLines: 200).complete else {
                    throw ImVaultSyncFailure.conflict
                }
                let qaAuthorized: Bool = await withCheckedContinuation { continuation in
                    ImVaultGuardedWrite.checkQAVaultEligibility(for: id) { result in
                        continuation.resume(returning: (try? result.get()) == true)
                    }
                }
                let result: Result<ImVaultCommitOutcome, Error> =
                    await withCheckedContinuation { continuation in
                        ImVaultGuardedWrite.commitAuthorized(
                            draft: draft, userConfirmedDiff: true,
                            deviceQATestCopyConfirmed: qaAuthorized) { r in
                                continuation.resume(returning: r)
                            }
                    }
                switch result {
                case .success(let outcome):
                    proposal.state.noteStatus = .applied
                    let receipt = ImVaultWriteReceiptText.present(
                        .success(outcome), testCopy: qaAuthorized)
                    proposal.noteReceipt = receipt.title + " · " + receipt.detail
                case .failure(let error):
                    if case ImVaultSyncFailure.conflict = error {
                        proposal.state.noteStatus = .conflict
                    } else {
                        proposal.state.noteStatus = .failed
                    }
                    proposal.noteReceipt = error.localizedDescription
                }
            } catch {
                if case ImVaultSyncFailure.conflict = error {
                    proposal.state.noteStatus = .conflict
                } else {
                    proposal.state.noteStatus = .failed
                }
                proposal.noteReceipt = error.localizedDescription
            }
            guard await saveProposal(proposal) else {
                showResult(V3L("写回回执未能保存"),
                    V3L("文件结果不明，请先检查目标和本机恢复副本；不可重试卡片，避免失配。"))
                return
            }
        }
        if proposal.state.needsCardAction {
            proposal.state.cardStatus = .applying
            guard await saveProposal(proposal) else {
                showResult(V3L("卡片状态无法保存"), V3L("未修改数据库。"))
                return
            }
            do {
                guard let id = proposal.cardID, let original = proposal.cardBaseQuestion,
                      let replacement = proposal.cardEditedQuestion,
                      let revision = proposal.cardContentRevision,
                      let card = try await repository.content(for: id) else {
                    throw ReviewWCDBError.missingCard
                }
                if let note = proposal.noteIdentity {
                    guard let link = card.sourceNotePath,
                          (try? ImpressBatchSourceKey.decode(link)) == note else {
                        throw ImVaultSyncFailure.wrongVault
                    }
                }
                switch ImDuplexCardVersionGate.decide(
                    expectedContentRevision: revision, currentContentRevision: card.contentRevision,
                    baseQuestion: original, baseAnswer: proposal.cardBaseAnswer,
                    proposedQuestion: replacement, proposedAnswer: proposal.cardEditedAnswer,
                    currentQuestion: card.question, currentAnswer: card.answerText) {
                case .unchanged, .alreadyApplied:
                    proposal.state.cardStatus = .applied
                    proposal.cardReceipt = V3L("原卡内容已一致；未重复保存、未评分。")
                case .conflict:
                    proposal.state.cardStatus = .conflict
                    proposal.cardReceipt = V3L("原卡内容已被其他编辑修改，拒绝覆盖。")
                case .safeToWrite:
                    guard let queue = try await repository.fetchQueueCandidates()
                            .first(where: { $0.cardID == id }),
                          queue.revision == proposal.cardReviewRevision else {
                        throw ReviewWCDBError.revisionConflict
                    }
                    try await repository.updateManagedCard(
                        WCDBV3CardInput(cardID: id, question: replacement,
                            answerText: proposal.cardEditedAnswer, choices: card.choices,
                            correctIndices: card.correctIndices, cardType: card.cardType,
                            imageData: card.imageData, sourceNotePath: card.sourceNotePath),
                        expectedRevision: queue.revision,
                        expectedContentRevision: revision, origin: .approvedAI)
                    proposal.state.cardStatus = .applied
                    proposal.cardReceipt = V3L("原卡已按确认内容更新；cardID 与 FSRS 历史保留。")
                }
            } catch {
                if case ReviewWCDBError.contentConflict = error {
                    proposal.state.cardStatus = .conflict
                } else if case ReviewWCDBError.revisionConflict = error {
                    proposal.state.cardStatus = .conflict
                } else {
                    proposal.state.cardStatus = .failed
                }
                proposal.cardReceipt = error.localizedDescription
            }
            guard await saveProposal(proposal) else {
                showResult(V3L("卡片回执未能保存"),
                    V3L("请从原卡重新读取当前版本，确认是否已经更新；不可盲目重试。"))
                return
            }
        }
        showResult(proposal.state.completed ? V3L("所选修改已处理") : V3L("存在未完成的修改"),
            (proposal.noteReceipt ?? V3L("笔记未选择")) + "\n\n" +
            (proposal.cardReceipt ?? V3L("原卡未选择")) + "\n\n" +
            V3L("所有回执存于原 Chat 会话；失败目标仅允许再次手动核查后重试。"))
    }

    private enum UndoTarget { case note, card }

    @objc private func openUndoOptions() {
        guard !committing else { return }
        let actions = UIAlertController(title: V3L("撤销已执行的目标"),
            message: V3L("每个目标单独预览、确认及记录回执。不会自动覆盖后续人工编辑。"),
            preferredStyle: .actionSheet)
        if [.applied, .undoing].contains(proposal.state.noteStatus),
           proposal.noteIdentity != nil {
            actions.addAction(UIAlertAction(title: V3L("撤销笔记改动"),
                style: .default) { [weak self] _ in
                Task { await self?.prepareUndo(.note) }
            })
        }
        if [.applied, .undoing].contains(proposal.state.cardStatus),
           proposal.cardID != nil {
            actions.addAction(UIAlertAction(title: V3L("撤销原卡改动"),
                style: .default) { [weak self] _ in
                Task { await self?.prepareUndo(.card) }
            })
        }
        actions.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        actions.popoverPresentationController?.barButtonItem = undoBarItem
        present(actions, animated: true)
    }

    private func prepareUndo(_ target: UndoTarget) async {
        guard !committing else { return }
        do {
            let details: String
            switch target {
            case .note:
                guard let id = proposal.noteIdentity,
                      let existing = try ImVaultPrivateStore.loadDraft(identity: id) else {
                    throw ImVaultSyncFailure.conflict
                }
                let inverse = try ImpressDuplexUndoGate.inverseDraft(existing,
                    expectedBaseDigest: proposal.noteBaseDigest,
                    expectedAppliedDigest: proposal.noteEditedDigest)
                let qaEnabled: Bool = await withCheckedContinuation { c in
                    ImVaultGuardedWrite.checkQAVaultEligibility(for: id) { answer in
                        c.resume(returning: (try? answer.get()) == true)
                    }
                }
                guard ImVaultGuardedWrite.productionWriteEnabled || qaEnabled else {
                    throw ImVaultSyncFailure.writesLocked
                }
                let current: ImVaultRawDocument = try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<ImVaultRawDocument, Error>) in
                    ImVaultReadSync.shared.read(id) { outcome in
                        continuation.resume(with: outcome)
                    }
                }
                guard current.identity == id else { throw ImVaultSyncFailure.wrongVault }
                let decision = inverse.decision(against: current.sourceBytes)
                guard decision == .safeToWrite || decision == .alreadyApplied else {
                    throw ImVaultSyncFailure.conflict
                }
                let diff = ImVaultDiff.summary(
                    base: inverse.baseText, edited: inverse.editedText, maximumLines: 200)
                guard diff.complete else { throw ImVaultSyncFailure.previewTruncated }
                details = V3L("撤销笔记改动") + "\n" + id.relativePath +
                    "\nExpected SHA-256: " + (proposal.noteEditedDigest ?? "?") +
                    "\n" + V3L("目标恢复 SHA-256：") + (proposal.noteBaseDigest ?? "?") +
                    "\n\n" + diff.text
            case .card:
                guard let id = proposal.cardID,
                      let oldRevision = proposal.cardContentRevision,
                      let card = try await repository.content(for: id),
                      let revised = proposal.cardEditedQuestion,
                      let original = proposal.cardBaseQuestion else {
                    throw ReviewWCDBError.missingCard
                }
                let decision = ImDuplexCardVersionGate.decide(
                    expectedContentRevision: oldRevision + 1,
                    currentContentRevision: card.contentRevision,
                    baseQuestion: revised, baseAnswer: proposal.cardEditedAnswer,
                    proposedQuestion: original, proposedAnswer: proposal.cardBaseAnswer,
                    currentQuestion: card.question, currentAnswer: card.answerText)
                guard decision == .safeToWrite || decision == .alreadyApplied else {
                    throw ReviewWCDBError.contentConflict
                }
                details = V3L("撤销原卡改动") + "\ncardID: " + id.uuidString +
                    "\nContent revision: " + String(oldRevision + 1) +
                    "\n\n" + V3L("原题目：") + revised +
                    "\n\n" + V3L("恢复题目：") + original +
                    "\n\n" + V3L("原答案：") + (proposal.cardEditedAnswer ?? "") +
                    "\n\n" + V3L("恢复答案：") + (proposal.cardBaseAnswer ?? "")
            }
            let page = ImpressDuplexUndoReviewController(content: details) { [weak self] in
                guard let self else { return .failure(WCDBV3ChatStorageError.invalidRecord) }
                do {
                    return .success(try await self.executeUndo(target))
                } catch { return .failure(error) }
            }
            navigationController?.pushViewController(page, animated: true)
        } catch {
            showResult(V3L("无法安全撤销"), error.localizedDescription)
        }
    }

    private func executeUndo(_ target: UndoTarget) async throws -> String {
        guard !committing else { throw WCDBV3ChatStorageError.conflict }
        committing = true
        updateConfirmation()
        defer {
            committing = false
            refreshPreview()
        }
        switch target {
        case .note:
            guard [.applied, .undoing].contains(proposal.state.noteStatus),
                  let id = proposal.noteIdentity,
                  let existing = try ImVaultPrivateStore.loadDraft(identity: id) else {
                throw ImVaultSyncFailure.conflict
            }
            let inverse = try ImpressDuplexUndoGate.inverseDraft(existing,
                expectedBaseDigest: proposal.noteBaseDigest,
                expectedAppliedDigest: proposal.noteEditedDigest)
            let qaCopy: Bool = await withCheckedContinuation { c in
                ImVaultGuardedWrite.checkQAVaultEligibility(for: id) { response in
                    c.resume(returning: (try? response.get()) == true)
                }
            }
            // Do not persist an undo intent when no authorized source
            // target is available. Production Vault remains permanently gated.
            guard ImVaultGuardedWrite.productionWriteEnabled || qaCopy else {
                throw ImVaultSyncFailure.writesLocked
            }
            if proposal.state.noteStatus != .undoing {
                var starting = proposal
                starting.state.noteStatus = .undoing
                guard await saveProposal(starting) else {
                    throw WCDBV3ChatStorageError.conflict
                }
                proposal = starting
            }
            do {
                let result: Result<ImVaultCommitOutcome, Error> =
                    await withCheckedContinuation { c in
                        ImVaultGuardedWrite.commitAuthorized(
                            draft: inverse, userConfirmedDiff: true,
                            deviceQATestCopyConfirmed: qaCopy) { result in
                                c.resume(returning: result)
                            }
                    }
                let outcome = try result.get()
                guard case .unchanged = outcome else {
                    var completed = proposal
                    completed.state.noteStatus = .reverted
                    completed.noteReceipt = (completed.noteReceipt ?? "") +
                        "\n" + V3L("已按版本校验撤销笔记；本机字节回读，不代表 iCloud 远端同步。")
                    guard await saveProposal(completed) else {
                        throw WCDBV3ChatStorageError.conflict
                    }
                    proposal = completed
                    return completed.noteReceipt ?? ""
                }
                throw ImVaultSyncFailure.verificationFailed
            } catch {
                // Undo intent is durable. Do not auto-replay it after restart.
                var failed = proposal
                failed.noteReceipt = (failed.noteReceipt ?? "") +
                    "\n" + V3L("撤销待核查：") + error.localizedDescription
                if await saveProposal(failed) { proposal = failed }
                throw error
            }
        case .card:
            guard [.applied, .undoing].contains(proposal.state.cardStatus),
                  let id = proposal.cardID, let revision = proposal.cardContentRevision,
                  let revised = proposal.cardEditedQuestion,
                  let original = proposal.cardBaseQuestion else {
                throw ReviewWCDBError.missingCard
            }
            if proposal.state.cardStatus != .undoing {
                var starting = proposal
                starting.state.cardStatus = .undoing
                guard await saveProposal(starting) else { throw WCDBV3ChatStorageError.conflict }
                proposal = starting
            }
            do {
                guard let current = try await repository.content(for: id) else {
                    throw ReviewWCDBError.missingCard
                }
                switch ImDuplexCardVersionGate.decide(
                    expectedContentRevision: revision + 1,
                    currentContentRevision: current.contentRevision,
                    baseQuestion: revised, baseAnswer: proposal.cardEditedAnswer,
                    proposedQuestion: original, proposedAnswer: proposal.cardBaseAnswer,
                    currentQuestion: current.question, currentAnswer: current.answerText) {
                case .conflict, .unchanged:
                    throw ReviewWCDBError.contentConflict
                case .alreadyApplied:
                    break
                case .safeToWrite:
                    guard let queue = try await repository.fetchQueueCandidates()
                        .first(where: { $0.cardID == id }) else {
                        throw ReviewWCDBError.missingCard
                    }
                    // Use the CURRENT FSRS revision for CAS: a review between
                    // original approval and undo must NOT reset the scheduler.
                    try await repository.updateManagedCard(
                        WCDBV3CardInput(cardID: id, question: original,
                            answerText: proposal.cardBaseAnswer, choices: current.choices,
                            correctIndices: current.correctIndices, cardType: current.cardType,
                            imageData: current.imageData, sourceNotePath: current.sourceNotePath),
                        expectedRevision: queue.revision,
                        expectedContentRevision: revision + 1, origin: .restored)
                }
                var completed = proposal
                completed.state.cardStatus = .reverted
                completed.cardReceipt = (completed.cardReceipt ?? "") +
                    "\n" + V3L("原卡已安全恢复旧内容；cardID、FSRS 评分和中间内容版本均保留。")
                guard await saveProposal(completed) else { throw WCDBV3ChatStorageError.conflict }
                proposal = completed
                return completed.cardReceipt ?? ""
            } catch {
                var failed = proposal
                failed.cardReceipt = (failed.cardReceipt ?? "") +
                    "\n" + V3L("撤销待核查：") + error.localizedDescription
                if await saveProposal(failed) { proposal = failed }
                throw error
            }
        }
    }

    private func showResult(_ name: String, _ message: String) {
        let alert = UIAlertController(title: name, message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(alert, animated: true)
    }
}
