import UIKit
import UniformTypeIdentifiers
import ImpressReviewCore

// R04.2-C authoring remains local until explicit confirmation. Candidate
// editors do not touch WCDB; only the batch coordinator owns the final commit.
@MainActor
struct ImpressV3BatchCandidate {
    let line: Int
    let raw: String
    var issues: [String]
    var draft: ImpressV3CardDraft
    var reviewed = false

    init(parsed: ImpressBatchParsedRow, sourceKey: String?) {
        line = parsed.line
        raw = parsed.raw
        issues = parsed.issues
        var value = ImpressV3CardDraft()
        value.question = parsed.question
        value.answer = parsed.answer
        value.sourceNotePath = sourceKey
        if parsed.isChoice {
            value.kind = .multipleChoice
            value.allowsMultipleCorrect = parsed.correctIndices.count > 1
            value.choices = parsed.choices.enumerated().map {
                ImpressV3CardDraft.Choice(text: $0.element,
                    isCorrect: parsed.correctIndices.contains($0.offset))
            }
        }
        draft = value
    }

    var problem: String? {
        if !reviewed, let sourceIssue = issues.first { return sourceIssue }
        do {
            _ = try draft.validatedInput()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func fromValidated(_ input: WCDBV3CardInput, old: ImpressV3BatchCandidate) -> Self {
        var candidate = old
        candidate.reviewed = true
        var draft = ImpressV3CardDraft()
        draft.kind = CardType(rawValue: input.cardType) ?? .standard
        draft.question = input.question
        draft.answer = input.answerText ?? ""
        draft.imageData = input.imageData
        draft.sourceNotePath = input.sourceNotePath
        if input.cardType == CardType.multipleChoice.rawValue {
            let selections = Set((input.correctIndices ?? "").split(separator: ",")
                .compactMap { Int($0) })
            draft.allowsMultipleCorrect = selections.count > 1
            draft.choices = (input.choices ?? "").components(separatedBy: "\n")
                .enumerated().map { index, text in
                    ImpressV3CardDraft.Choice(text: text, isCorrect: selections.contains(index))
                }
        }
        candidate.draft = draft
        return candidate
    }
}

@MainActor
final class ImpressV3BatchImportViewController: UIViewController, UIDocumentPickerDelegate,
                                                UITextViewDelegate {
    var onCommit: (([WCDBV3CardInput]) async throws -> Void)?

    private let formatPicker = UISegmentedControl(items: ["文本", "CSV", "TSV", "Markdown"])
    private let editor = UITextView()
    private let sourceLabel = UILabel()
    private var authorizedIdentity: ImVaultFileIdentity?
    private var reading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "批量导入"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "预览", style: .done, target: self, action: #selector(preview))
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

        let intro = UILabel()
        intro.text = "选择输入格式，在本机解析。预览和逐题校验通过后才会写入闪卡数据库。"
        intro.numberOfLines = 0
        intro.font = .preferredFont(forTextStyle: .subheadline)
        intro.adjustsFontForContentSizeCategory = true
        intro.textColor = .secondaryLabel
        stack.addArrangedSubview(intro)
        formatPicker.selectedSegmentIndex = 0
        stack.addArrangedSubview(formatPicker)
        let buttons = UIStackView()
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        buttons.addArrangedSubview(actionButton("选择文件", icon: "doc", selector: #selector(chooseFile)))
        buttons.addArrangedSubview(actionButton("Obsidian 笔记", icon: "folder", selector: #selector(chooseVault)))
        stack.addArrangedSubview(buttons)
        sourceLabel.numberOfLines = 0
        sourceLabel.font = .preferredFont(forTextStyle: .caption1)
        sourceLabel.adjustsFontForContentSizeCategory = true
        sourceLabel.textColor = .secondaryLabel
        sourceLabel.text = "粘贴文本，或选择 CSV / TSV / Markdown 文件。"
        stack.addArrangedSubview(sourceLabel)
        editor.font = .preferredFont(forTextStyle: .body)
        editor.adjustsFontForContentSizeCategory = true
        editor.backgroundColor = .secondarySystemGroupedBackground
        editor.textColor = .label
        editor.layer.cornerRadius = 12
        editor.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        editor.accessibilityLabel = "本地批量导入原始文本"
        editor.delegate = self
        stack.addArrangedSubview(editor)
        editor.heightAnchor.constraint(greaterThanOrEqualToConstant: 270).isActive = true
        let hint = UILabel()
        hint.numberOfLines = 0
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.adjustsFontForContentSizeCategory = true
        hint.textColor = .secondaryLabel
        hint.text = "文本/Markdown：Q: 问题、A: 答案。CSV/TSV：question、answer；选择题另提供 type=choice、options=A|B|C、correct=1,3（从 1 起）。无法识别的内容保留原文供修正。"
        stack.addArrangedSubview(hint)
    }

    private func actionButton(_ title: String, icon: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.bordered()
            config.title = title
            config.image = UIImage(systemName: icon)
            config.imagePadding = 5
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.setImage(UIImage(systemName: icon), for: .normal)
        }
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }

    func textViewDidChange(_ textView: UITextView) {
        if authorizedIdentity != nil {
            authorizedIdentity = nil
            sourceLabel.text = "已修改输入文本，解除原 Obsidian 来源关联，避免来源错配。"
        }
    }

    @objc private func chooseFile() {
        let formats: [UTType] = [.plainText, .commaSeparatedText,
            UTType(filenameExtension: "tsv") ?? .plainText,
            UTType(filenameExtension: "md") ?? .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: formats, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= ImpressBatchParser.maximumBytes
            else { throw CocoaError(.fileReadTooLarge) }
            let bytes = try Data(contentsOf: url)
            guard bytes.count <= ImpressBatchParser.maximumBytes,
                  let text = String(data: bytes, encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            authorizedIdentity = nil
            editor.text = text
            sourceLabel.text = "本机文件 · " + url.lastPathComponent
            switch url.pathExtension.lowercased() {
            case "csv": formatPicker.selectedSegmentIndex = 1
            case "tsv": formatPicker.selectedSegmentIndex = 2
            case "md", "markdown": formatPicker.selectedSegmentIndex = 3
            default: formatPicker.selectedSegmentIndex = 0
            }
        } catch { showError("无法读取文件", error.localizedDescription) }
    }

    @objc private func chooseVault() {
        let picker = ImpressV3BatchVaultPickerViewController(style: .plain)
        picker.onChoose = { [weak self] identity in
            guard let self else { return }
            self.reading = true
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            ImVaultReadSync.shared.read(identity) { [weak self] result in
                guard let self else { return }
                self.reading = false
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                switch result {
                case .success(let document):
                    guard document.identity == identity else {
                        self.showError("来源不一致", "授权笔记的身份发生变化。")
                        return
                    }
                    guard document.sourceBytes.count <= ImpressBatchParser.maximumBytes else {
                        self.showError("文本过长", "导入文本不能超过 2MB。")
                        return
                    }
                    self.editor.text = document.markdown
                    self.authorizedIdentity = identity
                    self.formatPicker.selectedSegmentIndex = 3
                    self.sourceLabel.text = identity.relativePath + " · 授权 Vault（仅读）"
                case .failure(let error):
                    self.showError("无法读取笔记", error.localizedDescription)
                }
            }
        }
        let nav = UINavigationController(rootViewController: picker)
        present(nav, animated: true)
    }

    @objc private func preview() {
        guard !reading else { return }
        let formats: [ImpressBatchFormat] = [.text, .csv, .tsv, .markdown]
        let format = formats[formats.indices.contains(formatPicker.selectedSegmentIndex)
                             ? formatPicker.selectedSegmentIndex : 0]
        let parsed = ImpressBatchParser.parse(editor.text, as: format)
        guard !parsed.isEmpty else {
            showError("没有候选卡片", "先粘贴或选择包含问题和答案的文本。")
            return
        }
        do {
            let source = try authorizedIdentity.map(ImpressBatchSourceKey.encode)
            let rows = parsed.map { ImpressV3BatchCandidate(parsed: $0, sourceKey: source) }
            let preview = ImpressV3BatchPreviewViewController(rows: rows)
            preview.onCommit = onCommit
            navigationController?.pushViewController(preview, animated: true)
        } catch { showError("来源身份无效", error.localizedDescription) }
    }

    @objc private func cancel() {
        guard editor.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let alert = UIAlertController(title: "放弃这次导入？",
                message: "未确认的候选不会写入数据库，也不会修改来源笔记。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "继续编辑", style: .cancel))
            alert.addAction(UIAlertAction(title: "放弃", style: .destructive) { [weak self] _ in
                self?.dismiss(animated: true)
            })
            present(alert, animated: true)
            return
        }
        dismiss(animated: true)
    }

    private func showError(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

@MainActor
final class ImpressV3BatchVaultPickerViewController: UITableViewController {
    var onChoose: ((ImVaultFileIdentity) -> Void)?
    private var notes: [ImVaultIndexNote] = []
    private var filtered: [ImVaultIndexNote] = []
    private let search = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选择已授权笔记"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        search.obscuresBackgroundDuringPresentation = false
        search.searchResultsUpdater = self
        navigationItem.searchController = search
        ImVaultReadSync.shared.refresh { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let index):
                self.notes = index.notes
                self.filterNotes()
            case .failure(let error):
                let alert = UIAlertController(title: "Vault 未授权或无法读取",
                    message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func filterNotes() {
        let q = search.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        filtered = q.isEmpty ? notes : notes.filter {
            $0.identity.relativePath.localizedCaseInsensitiveContains(q)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "note"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = filtered[indexPath.row].title
        content.secondaryText = filtered[indexPath.row].identity.relativePath
        content.image = UIImage(systemName: "doc.text")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let identity = filtered[indexPath.row].identity
        let callback = onChoose
        dismiss(animated: true) { callback?(identity) }
    }

    @objc private func cancel() { dismiss(animated: true) }
}

extension ImpressV3BatchVaultPickerViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) { filterNotes() }
}

@MainActor
final class ImpressV3BatchPreviewViewController: UITableViewController {
    var onCommit: (([WCDBV3CardInput]) async throws -> Void)?
    private(set) var rows: [ImpressV3BatchCandidate]
    private var saving = false
    private var commitButton: UIBarButtonItem?

    init(rows: [ImpressV3BatchCandidate]) {
        self.rows = rows
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(rows:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "导入预览"
        navigationItem.largeTitleDisplayMode = .never
        let commit = UIBarButtonItem(title: "全部导入", style: .done,
                                     target: self, action: #selector(commitBatch))
        commitButton = commit
        navigationItem.rightBarButtonItem = commit
        refreshValidation()
    }

    private func key(for candidate: ImpressV3BatchCandidate) -> String {
        let q = candidate.draft.question.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
        return (candidate.draft.sourceNotePath ?? "") + "\u{001F}" + q
    }

    private func problems() -> [String?] {
        var seen = Set<String>()
        return rows.map { candidate in
            if let error = candidate.problem { return error }
            if !seen.insert(key(for: candidate)).inserted { return "与另一条候选问题重复。" }
            return nil
        }
    }

    private func refreshValidation() {
        let errors = problems()
        let good = errors.filter { $0 == nil }.count
        commitButton?.isEnabled = !saving && !rows.isEmpty && good == rows.count
        commitButton?.title = "导入 \(good)/\(rows.count)"
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        let valid = problems().filter { $0 == nil }.count
        return "可导入 \(valid) / \(rows.count) · 点选修正，左滑可移除"
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "candidate")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "candidate")
        let value = rows[indexPath.row]
        let issue = problems()[indexPath.row]
        var cfg = UIListContentConfiguration.subtitleCell()
        cfg.text = value.draft.question.isEmpty
            ? "第 \(value.line) 行 · 待填写问题"
            : value.draft.question
        cfg.secondaryText = issue.map { "第 \(value.line) 行 · " + $0 }
            ?? "第 \(value.line) 行 · 校验通过"
        cfg.secondaryTextProperties.color = issue == nil ? .secondaryLabel : .systemOrange
        cfg.textProperties.numberOfLines = 2
        cfg.secondaryTextProperties.numberOfLines = 2
        cfg.image = UIImage(systemName: issue == nil ? "checkmark.circle" : "exclamationmark.circle")
        cfg.imageProperties.tintColor = issue == nil ? .systemGreen : .systemOrange
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !saving else { return }
        let candidate = rows[indexPath.row]
        let composer = ImpressV3CardComposerViewController(draft: candidate.draft)
        composer.onSave = { [weak self] input in
            // This is preview editing, NOT a database write.
            guard let self, self.rows.indices.contains(indexPath.row) else {
                throw CocoaError(.userCancelled)
            }
            self.rows[indexPath.row] = .fromValidated(input, old: self.rows[indexPath.row])
            self.refreshValidation()
        }
        let nav = UINavigationController(rootViewController: composer)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            nav.sheetPresentationController?.detents = [.large()]
        }
        present(nav, animated: true)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard !saving, editingStyle == .delete else { return }
        rows.remove(at: indexPath.row)
        refreshValidation()
    }

    @objc private func commitBatch() {
        guard !saving, !rows.isEmpty, problems().allSatisfy({ $0 == nil }),
              let commit = onCommit else { return }
        let inputs: [WCDBV3CardInput]
        do { inputs = try rows.map { try $0.draft.validatedInput() } }
        catch {
            showError("预览校验失败", error.localizedDescription)
            return
        }
        saving = true
        refreshValidation()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await commit(inputs)
                let alert = UIAlertController(title: "已原子导入 \(inputs.count) 张卡片",
                    message: "全部写入成功。正在进行的复习队列未重置；原始文件未修改。",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "完成", style: .default) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                self.present(alert, animated: true)
            } catch {
                self.saving = false
                self.refreshValidation()
                self.showError("整批导入失败", "没有提交任何部分数据。\n" + error.localizedDescription)
            }
        }
    }

    private func showError(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
