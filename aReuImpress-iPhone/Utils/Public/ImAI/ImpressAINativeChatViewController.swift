import UIKit
import ImpressReviewCore

/// V1 native API chat. Uses the same per-business AI registry as question
/// generation, but its request/response is ordinary text, NOT question JSON.
/// Nothing is automatically appended to learning history or source Markdown.
@MainActor
final class ImpressAINativeChatViewController: UIViewController,
                                                UITableViewDataSource, UITextViewDelegate {
    private let sourceQuestion: String?
    private let sourceAnswer: String?
    private var contextChoiceMade = false
    private var includeCardContext = false
    private var history: [ImpressAIChatTurn] = []
    private var sending = false

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let messageInput = UITextView()
    private let sendButton = UIButton(type: .system)
    private let inputBar = UIView()
    private let privacyLabel = UILabel()

    init(question: String? = nil, answer: String? = nil) {
        self.sourceQuestion = question
        self.sourceAnswer = answer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selected = try? ImpressAIConfigStore.shared.registry.resolve(.conversation) {
            navigationItem.prompt = selected.connection.title + " · " + selected.model.identifier
        } else {
            navigationItem.prompt = V3L("请先选择免费对话模型")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("AI 讨论")
        view.backgroundColor = ImpressV3Appearance.page
        navigationItem.largeTitleDisplayMode = .never

        tableView.dataSource = self
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
        privacyLabel.text = V3L("讨论记录仅在本页面保留，不会自动写入 Obsidian。")

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
        sendButton.addTarget(self, action: #selector(submitMessage), for: .touchUpInside)
        sendButton.accessibilityLabel = V3L("发送消息")
        sendButton.accessibilityIdentifier = "impress.ai.chat.send"
        sendButton.isEnabled = false

        inputBar.backgroundColor = .clear
        for element in [tableView, inputBar, privacyLabel] {
            element.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(element)
        }
        for element in [messageInput, sendButton] {
            element.translatesAutoresizingMaskIntoConstraints = false
            inputBar.addSubview(element)
        }
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
    }

    func textViewDidChange(_ textView: UITextView) {
        let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        sendButton.isEnabled = !sending && !content.isEmpty && content.utf8.count <= 12_000
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        history.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "turn")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "turn")
        let turn = history[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = turn.role == .user ? V3L("我") : V3L("AI")
        content.secondaryText = turn.text
        content.textProperties.font = ImpressV3Appearance.Typography.caption
        content.textProperties.color = ImpressV3Appearance.secondaryText
        content.secondaryTextProperties.font = ImpressV3Appearance.Typography.body
        content.secondaryTextProperties.color = ImpressV3Appearance.primaryText
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.backgroundColor = turn.role == .user
            ? ImpressV3Appearance.reviewActionSurface : ImpressV3Appearance.surface
        cell.selectionStyle = .none
        return cell
    }

    @objc private func submitMessage() {
        let text = messageInput.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.count <= 12_000, !sending else { return }

        let route: ImpressAIResolvedRoute
        do { route = try ImpressAIConfigStore.shared.registry.resolve(.conversation) }
        catch {
            let alert = UIAlertController(title: V3L("尚未配置对话模型"),
                message: V3L("请先在「设置 → AI 服务」选择对话使用的连接与模型。"),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
            alert.addAction(UIAlertAction(title: V3L("打开 AI 服务"), style: .default) { [weak self] _ in
                self?.navigationController?.pushViewController(
                    ImpressAISettingsViewController(), animated: true)
            })
            present(alert, animated: true)
            return
        }

        if !contextChoiceMade, let question = sourceQuestion, !question.isEmpty {
            let alert = UIAlertController(title: V3L("是否附带当前卡片？"),
                message: V3L("只有你确认后，本次讨论才会将卡片问题与参考答案一起发送给所选的 API 服务商。"),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
            alert.addAction(UIAlertAction(title: V3L("仅发送输入内容"), style: .default) { [weak self] _ in
                self?.contextChoiceMade = true
                self?.includeCardContext = false
                self?.performSend(text, route: route)
            })
            alert.addAction(UIAlertAction(title: V3L("附带当前卡片"), style: .default) { [weak self] _ in
                self?.contextChoiceMade = true
                self?.includeCardContext = true
                self?.performSend(text, route: route)
            })
            present(alert, animated: true)
            return
        }
        performSend(text, route: route)
    }

    private func performSend(_ message: String, route: ImpressAIResolvedRoute) {
        guard !sending else { return }
        let snapshot = history
        // Preserve complete user/assistant pairs when the context window fills.
        // An arbitrary suffix could start with an assistant turn.
        var newHistory = history.count >= 18 ? Array(history.suffix(16)) : history
        newHistory.append(ImpressAIChatTurn(role: .user, text: message))
        sending = true
        messageInput.text = ""
        sendButton.isEnabled = false
        privacyLabel.text = V3L("正在请求模型…")
        history = newHistory
        reloadAndScroll()

        var system = V3L("以第一性原理和奥卡姆剃刀分析问题，明确假设、证据与边界。不编造笔记内容。")
        if includeCardContext, let question = sourceQuestion, !question.isEmpty {
            system += "\n" + V3L("当前卡片的问题：") + question
            if let answer = sourceAnswer, !answer.isEmpty {
                system += "\n" + V3L("当前卡片的参考答案：") + answer
            }
        }
        Task {
            do {
                let reply = try await ImpressAIHTTPClient.shared.converse(
                    route: route, system: system, turns: newHistory)
                history.append(ImpressAIChatTurn(role: .assistant, text: reply))
                if history.count > 18 { history = Array(history.suffix(18)) }
                privacyLabel.text = V3L("讨论记录仅在本页面保留，不会自动写入 Obsidian。")
            } catch {
                history = snapshot
                messageInput.text = message
                privacyLabel.text = V3L("请求失败，输入内容已保留。")
                let alert = UIAlertController(title: V3L("AI 对话失败"),
                    message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
                present(alert, animated: true)
            }
            sending = false
            textViewDidChange(messageInput)
            reloadAndScroll()
        }
    }

    private func reloadAndScroll() {
        tableView.reloadData()
        if !history.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: history.count - 1, section: 0),
                                  at: .bottom, animated: false)
        }
    }
}
