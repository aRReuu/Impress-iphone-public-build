import UIKit

// R04.2-D: reusable local writing prompts. No AI endpoint, notes, chat history,
// or credentials are read, written or sent from this store.
struct ImpressV3PromptTemplate: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
    }
}

enum ImpressV3PromptLibrary {
    enum Failure: LocalizedError {
        case invalid, tooMany, duplicate
        var errorDescription: String? {
            switch self {
            case .invalid: return "名称和提示词不能为空，名称不超过 60 字、正文不超过 6000 字。"
            case .tooMany: return "最多可保存 60 条提示词。"
            case .duplicate: return "提示词 ID 或名称重复，请调整后重试。"
            }
        }
    }
    static let storageKey = "ImpressV3LocalPromptLibraryV1"
    static let defaults: [ImpressV3PromptTemplate] = [
        .init(title: "费曼总结", content: "请根据我主动提供的内容，先用浅显语言解释核心机制，再指出概念间的因果关系、隐含前提和可能反例。使用第一性原理，避免冗余；不要将未经验证的观点当作事实。"),
        .init(title: "生成选择题", content: "根据我本次明确提供的上下文生成检验理解的选择题。给出题干、2–6 个相互区分的选项、正确答案及简明解释；必要时设计多选题，禁止在依据不足时推测正确项。"),
        .init(title: "生成问题和答案", content: "仅根据我提供的材料提取有价值的理解性问题，提供精确、简洁的参考答案，并标注材料不足或存在争议的内容。优先机制、边界条件与反例，而非机械摘抄。")
    ]
    static func load(from store: UserDefaults = .standard) -> [ImpressV3PromptTemplate] {
        guard let saved = store.data(forKey: storageKey) else { return defaults }
        // Empty array means the user intentionally removed all templates.
        return (try? JSONDecoder().decode([ImpressV3PromptTemplate].self, from: saved)) ?? defaults
    }
    static func save(_ items: [ImpressV3PromptTemplate],
                     to store: UserDefaults = .standard) throws {
        guard items.count <= 60 else { throw Failure.tooMany }
        let titles = items.map {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive],
                         locale: Locale(identifier: "en_US_POSIX"))
        }
        guard Set(items.map(\.id)).count == items.count,
              Set(titles).count == titles.count else { throw Failure.duplicate }
        guard items.allSatisfy({
            let name = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = $0.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return !name.isEmpty && name.count <= 60 &&
                !body.isEmpty && body.count <= 6000
        }) else { throw Failure.invalid }
        store.set(try JSONEncoder().encode(items), forKey: storageKey)
    }
}

/// A compact native Settings destination, not a second global model setup.
@MainActor
final class ImpressV3PromptLibraryViewController: UITableViewController {
    private var templates: [ImpressV3PromptTemplate] = []

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "提示词"
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = ImpressV3Appearance.page
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(add))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "新增提示词"
        reloadTemplates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadTemplates()
    }

    private func reloadTemplates() {
        templates = ImpressV3PromptLibrary.load()
        tableView.reloadData()
        let empty = UILabel()
        empty.text = "暂无提示词。点右上角 ＋ 创建。"
        empty.textColor = ImpressV3Appearance.secondaryText
        empty.font = ImpressV3Appearance.Typography.body
        empty.numberOfLines = 0
        empty.textAlignment = .center
        tableView.backgroundView = templates.isEmpty ? empty : nil
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int { templates.count }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        "本机保存 · 可编辑、可复制"
    }
    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        "网页聊天不会自动收到提示词或私人笔记。在网页聊天中选择提示词后，会先复制到剪贴板，由你自行粘贴和发送。"
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = templates[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "prompt")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "prompt")
        var c = UIListContentConfiguration.subtitleCell()
        c.text = item.title
        c.secondaryText = item.content
        c.secondaryTextProperties.numberOfLines = 2
        c.textProperties.numberOfLines = 1
        c.image = UIImage(systemName: "text.alignleft")
        c.imageProperties.tintColor = ImpressV3Appearance.secondaryText
        cell.contentConfiguration = c
        cell.backgroundColor = ImpressV3Appearance.surface
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openEditor(existing: templates[indexPath.row])
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let id = templates[indexPath.row].id
        let copy = UIContextualAction(style: .normal, title: "复制") { [weak self] _, _, done in
            guard let self,
                  let selected = self.templates.first(where: { $0.id == id }) else {
                done(false); return
            }
            UIPasteboard.general.string = selected.content
            done(true)
        }
        copy.backgroundColor = .systemGray
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            guard let self else { done(false); return }
            let changed = self.templates.filter { $0.id != id }
            do {
                try ImpressV3PromptLibrary.save(changed)
                self.reloadTemplates()
                done(true)
            } catch {
                self.showFailure(error)
                done(false)
            }
        }
        return UISwipeActionsConfiguration(actions: [delete, copy])
    }

    @objc private func add() { openEditor(existing: nil) }

    private func openEditor(existing: ImpressV3PromptTemplate?) {
        let editor = ImpressV3PromptEditorViewController(template: existing)
        editor.onSave = { [weak self] next in
            guard let self else { throw CocoaError(.userCancelled) }
            var values = self.templates
            if let index = values.firstIndex(where: { $0.id == next.id }) {
                values[index] = next
            } else {
                values.append(next)
            }
            try ImpressV3PromptLibrary.save(values)
            self.reloadTemplates()
        }
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            nav.sheetPresentationController?.detents = [.large()]
        }
        present(nav, animated: true)
    }

    private func showFailure(_ error: Error) {
        let alert = UIAlertController(title: "提示词未保存",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

@MainActor
final class ImpressV3PromptEditorViewController: UIViewController {
    var onSave: ((ImpressV3PromptTemplate) throws -> Void)?
    private let original: ImpressV3PromptTemplate?
    private let titleField = UITextField()
    private let contentView = UITextView()

    init(template: ImpressV3PromptTemplate?) {
        original = template
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = true
    }
    required init?(coder: NSCoder) { fatalError("init(template:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = original == nil ? "新增提示词" : "编辑提示词"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = ImpressV3Appearance.page
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存", style: .done, target: self, action: #selector(save))
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        if #available(iOS 15.0, *) {
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor).isActive = true
        } else {
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        }
        let titleLabel = UILabel()
        titleLabel.text = "名称"
        titleLabel.font = ImpressV3Appearance.Typography.heading
        stack.addArrangedSubview(titleLabel)
        titleField.borderStyle = .none
        titleField.backgroundColor = ImpressV3Appearance.surface
        titleField.font = ImpressV3Appearance.Typography.body
        titleField.adjustsFontForContentSizeCategory = true
        titleField.layer.cornerRadius = ImpressV3Appearance.Radius.compactField
        titleField.placeholder = "例如：费曼总结"
        titleField.text = original?.title
        titleField.accessibilityLabel = "提示词名称"
        let nameRow = UIView()
        nameRow.addSubview(titleField)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: nameRow.leadingAnchor, constant: 12),
            titleField.trailingAnchor.constraint(equalTo: nameRow.trailingAnchor, constant: -12),
            titleField.topAnchor.constraint(equalTo: nameRow.topAnchor),
            titleField.bottomAnchor.constraint(equalTo: nameRow.bottomAnchor),
            titleField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
        nameRow.backgroundColor = ImpressV3Appearance.surface
        nameRow.layer.cornerRadius = ImpressV3Appearance.Radius.compactField
        stack.addArrangedSubview(nameRow)
        let instruction = UILabel()
        instruction.text = "内容"
        instruction.font = ImpressV3Appearance.Typography.heading
        stack.addArrangedSubview(instruction)
        contentView.font = ImpressV3Appearance.Typography.body
        contentView.adjustsFontForContentSizeCategory = true
        contentView.backgroundColor = ImpressV3Appearance.surface
        contentView.textColor = ImpressV3Appearance.primaryText
        contentView.layer.cornerRadius = ImpressV3Appearance.Radius.compactField
        contentView.textContainerInset = UIEdgeInsets(top: 12, left: 9, bottom: 12, right: 9)
        contentView.text = original?.content ?? ""
        contentView.accessibilityLabel = "可复制的提示词正文"
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true
        stack.addArrangedSubview(contentView)
        let note = UILabel()
        note.text = "只会在本机保存。调用时复制内容，不会自动发送到网页。"
        note.textColor = ImpressV3Appearance.secondaryText
        note.font = ImpressV3Appearance.Typography.footnote
        note.numberOfLines = 0
        stack.addArrangedSubview(note)
    }

    @objc private func save() {
        let next = ImpressV3PromptTemplate(id: original?.id ?? UUID(),
            title: titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            content: contentView.text.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            guard let callback = onSave else { throw CocoaError(.userCancelled) }
            try callback(next)
            dismiss(animated: true)
        } catch {
            let alert = UIAlertController(title: "无法保存", message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func cancel() {
        let changed = titleField.text != (original?.title ?? "") ||
            contentView.text != (original?.content ?? "")
        guard changed else { dismiss(animated: true); return }
        let alert = UIAlertController(title: "放弃未保存的提示词？", message: nil,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "继续编辑", style: .cancel))
        alert.addAction(UIAlertAction(title: "放弃", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
