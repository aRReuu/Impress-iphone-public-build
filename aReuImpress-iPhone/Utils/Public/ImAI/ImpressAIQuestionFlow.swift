import UIKit
import ImpressReviewCore

private struct ImpressAISectionItem {
    let id: String
    let heading: String
    let text: String
}

// Reads only a previously authorized, coordinated Vault document.
// Headings inside fenced code are ignored; duplicate headings remain distinct
// because IDs derive from sequence position rather than heading strings.
private enum ImpressAISectionExtractor {
    static func sections(in markdown: String) -> [ImpressAISectionItem] {
        let lines = markdown.components(separatedBy: .newlines)
        var sections: [ImpressAISectionItem] = []
        var buffer: [String] = []
        var current = "全文"
        var fenced: Character?
        func flush() {
            let text = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                sections.append(ImpressAISectionItem(id: "section-\(sections.count)", heading: current, text: text))
            }
            buffer.removeAll()
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                fenced = fenced == "`" ? nil : "`"
            } else if trimmed.hasPrefix("~~~") {
                fenced = fenced == "~" ? nil : "~"
            }
            if fenced == nil && trimmed.hasPrefix("#") &&
                trimmed.firstIndex(where: { $0 != "#" }) != nil {
                let stripped = trimmed.drop(while: { $0 == "#" })
                if stripped.first == " " {
                    flush()
                    current = String(stripped.dropFirst()).trimmingCharacters(in: .whitespaces)
                    buffer.append(line)
                    continue
                }
            }
            buffer.append(line)
        }
        flush()
        return sections
    }
}

@MainActor
final class ImpressAIQuestionGenerationViewController: UITableViewController {
    private let document: ImVaultRawDocument
    private let sections: [ImpressAISectionItem]
    private var selected: Set<String>
    private let quantityLabel = UILabel()
    private let stepper = UIStepper()
    private var running = false
    private var checkedSavedPool = false

    init(document: ImVaultRawDocument) {
        self.document = document
        sections = ImpressAISectionExtractor.sections(in: document.markdown)
        let total = document.markdown.utf8.count
        selected = total <= 24_000 ? Set(sections.map(\.id)) : Set(sections.prefix(1).map(\.id))
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(document:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("生成综合问题")
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.allowsMultipleSelection = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: V3L("生成"), style: .done, target: self, action: #selector(startGeneration))
        stepper.minimumValue = 1
        stepper.maximumValue = 20
        stepper.value = 5
        stepper.addTarget(self, action: #selector(updateCount), for: .valueChanged)
        quantityLabel.font = ImpressV3Appearance.Typography.body
        quantityLabel.textColor = ImpressV3Appearance.primaryText
        updateCount()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !checkedSavedPool else { return }
        checkedSavedPool = true
        do {
            guard let saved = try ImVaultPrivateStore.loadQuestionPool(
                identity: document.identity) else { return }
            guard saved.source.documentSHA256 == document.digest else {
                let alert = UIAlertController(title: V3L("源笔记已发生变化"),
                    message: V3L("旧候选池已保留，但来源版本不一致，禁止直接导入。请重新生成问题。"),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
                present(alert, animated: true)
                return
            }
            let alert = UIAlertController(title: V3L("恢复未完成的候选池？"),
                message: "\(saved.candidates.count) \(V3L("道候选题已在本机安全保存；恢复不会修改 Obsidian 或 FSRS。"))",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: V3L("重新生成"), style: .cancel))
            alert.addAction(UIAlertAction(title: V3L("恢复候选池"), style: .default) { [weak self] _ in
                guard let self else { return }
                let audited = ImpressAIQuestionValidator.audit(saved)
                self.navigationController?.pushViewController(
                    ImpressAIQuestionPoolViewController(document: self.document, pool: audited),
                    animated: true)
            })
            present(alert, animated: true)
        } catch { showFailure(error) }
    }

    @objc private func updateCount() {
        quantityLabel.text = "\(Int(stepper.value)) \(V3L("道综合题"))"
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : sections.count
    }
    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        section == 0 ? V3L("出题数量") : V3L("选择要分析的笔记章节")
    }
    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        section == 0
            ? V3L("默认5道综合理解与应用题，不要求AI为凑数量编造内容。")
            : V3L("只上传勾选章节及其文本，原始 Obsidian 文件保持只读。")
    }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        ImpressV3Appearance.styleGroupedCell(cell)
        if indexPath.section == 0 {
            cell.selectionStyle = .none
            let row = UIStackView(arrangedSubviews: [quantityLabel, stepper])
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .equalSpacing
            cell.contentView.addSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
            ])
        } else {
            let item = sections[indexPath.row]
            var ui = UIListContentConfiguration.subtitleCell()
            ui.text = item.heading.isEmpty ? V3L("未命名章节") : item.heading
            ui.secondaryText = "\(item.text.count) \(V3L("字符"))"
            ui.textProperties.font = ImpressV3Appearance.Typography.body
            cell.contentConfiguration = ui
            cell.accessoryType = selected.contains(item.id) ? .checkmark : .none
        }
        return cell
    }
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }
        let item = sections[indexPath.row]
        if selected.contains(item.id) { selected.remove(item.id) }
        else { selected.insert(item.id) }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    @objc private func startGeneration() {
        guard !running else { return }
        let config = ImpressAIConfigStore.shared.registry
        let resolved: ImpressAIResolvedRoute
        do { resolved = try config.resolve(.questionGeneration) }
        catch { showFailure(error); return }
        let chosen = sections.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { showFailure(ImpressAIContractError.invalidRequest); return }
        let source = ImpressAISource(vaultID: document.identity.vaultID,
                relativePath: document.identity.relativePath,
                documentSHA256: document.digest, heading: chosen.count == 1 ? chosen[0].heading : "多章节")
        let excerpts = chosen.map { item in
            ImpressAIExcerpt(id: item.id, source: source, text: item.text, sectionHeading: item.heading)
        }
        do { _ = try ImpressAIQuestionPrompt.input(excerpts) }
        catch { showFailure(ImpressAIServiceError.tooLarge); return }
        let alert = UIAlertController(title: V3L("确认发送所选笔记？"),
            message: "\(resolved.connection.title) / \(resolved.model.identifier)\n\n" +
                V3L("只发送已勾选章节给该云端 API 服务商，不会上传整个 Vault；原文不会被修改。"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: V3L("生成"), style: .default) { [weak self] _ in
            self?.performGeneration(source: source, excerpts: excerpts, route: resolved)
        })
        present(alert, animated: true)
    }

    private func performGeneration(source: ImpressAISource, excerpts: [ImpressAIExcerpt],
                                   route: ImpressAIResolvedRoute) {
        guard !running else { return }
        running = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        title = V3L("生成中…")
        Task {
            defer {
                running = false
                navigationItem.rightBarButtonItem?.isEnabled = true
                title = V3L("生成综合问题")
            }
            do {
                let prompt = ImpressAIQuestionPrompt.system(count: Int(stepper.value))
                let content = try ImpressAIQuestionPrompt.input(excerpts)
                let response = try await ImpressAIHTTPClient.shared.complete(
                    route: route, system: prompt, user: content)
                let questions = try ImpressAIQuestionPrompt.decode(response)
                let candidates = questions.map {
                    ImpressAIQuestionCandidate(question: $0.question, answer: $0.answer,
                        dimension: $0.dimension, evidenceIDs: $0.evidenceIDs)
                }
                let pool = ImpressAIQuestionPool(source: source, excerpts: excerpts,
                    requestedCount: Int(stepper.value), modelProfileID: route.model.id,
                    candidates: candidates)
                let audited = ImpressAIQuestionValidator.audit(pool)
                try ImVaultPrivateStore.saveQuestionPool(audited)
                let next = ImpressAIQuestionPoolViewController(document: document, pool: audited)
                navigationController?.pushViewController(next, animated: true)
            } catch { showFailure(error) }
        }
    }

    private func showFailure(_ error: Error) {
        let detail: String
        switch error as? ImpressAIContractError {
        case .unverifiedModel:
            detail = V3L("出题模型尚未通过 JSON 验证，请在 AI 服务中测试该模型后重试。")
        case .missingCredential:
            detail = V3L("出题模型未保存 API Key，请先在 AI 服务中配置凭据。")
        case .invalidRoute:
            detail = V3L("请先在 AI 服务 → 业务默认模型中选择出题模型。")
        case .disabled:
            detail = V3L("当前出题模型或连接已停用，请重新选择。")
        default:
            detail = error.localizedDescription
        }
        let alert = UIAlertController(title: V3L("无法生成问题"),
             message: detail, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(alert, animated: true)
    }
}

@MainActor
final class ImpressAIQuestionPoolViewController: UITableViewController {
    private let document: ImVaultRawDocument
    private var pool: ImpressAIQuestionPool
    private var committing = false

    init(document: ImVaultRawDocument, pool: ImpressAIQuestionPool) {
        self.document = document
        self.pool = pool
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(document:pool:)") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("问题候选池")
        tableView.backgroundColor = ImpressV3Appearance.page
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: V3L("加入卡片集"), style: .done, target: self, action: #selector(confirmImport))
        updateImportButton()
    }

    private func persistCandidateEdits() {
        do { try ImVaultPrivateStore.saveQuestionPool(pool) }
        catch { showFailure(error) }
    }

    private func updateImportButton() {
        let count = pool.candidates.filter { $0.selected && $0.issues.isEmpty }.count
        navigationItem.rightBarButtonItem?.title = "\(V3L("加入")) \(count) \(V3L("张"))"
        navigationItem.rightBarButtonItem?.isEnabled = count > 0 && !committing
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        pool.candidates.count
    }
    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        "\(pool.candidates.count)/\(pool.requestedCount) \(V3L("道候选 · 点选勾选，点信息按钮编辑"))"
    }
    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        V3L("来源引用仅供核对，不能单独证明答案正确。加入前请确认内容。")
    }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = pool.candidates[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.question
        content.secondaryText = item.issues.isEmpty
            ? item.dimension.rawValue + " · " + pool.source.relativePath
            : item.issues.joined(separator: "、")
        content.textProperties.font = ImpressV3Appearance.Typography.body
        content.textProperties.numberOfLines = 3
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .detailButton
        cell.imageView?.image = nil
        cell.accessoryView = nil
        cell.tintColor = ImpressV3Appearance.accent
        // Selection state is conveyed in the question title rather than mixing
        // a checkmark accessory with the editable detail button.
        if item.selected {
            content.text = "✓ " + item.question
            cell.contentConfiguration = content
        }
        ImpressV3Appearance.styleGroupedCell(cell)
        return cell
    }
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        pool.candidates[indexPath.row].selected.toggle()
        persistCandidateEdits()
        tableView.reloadRows(at: [indexPath], with: .none)
        updateImportButton()
    }
    override func tableView(_ tableView: UITableView,
                            accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let row = pool.candidates[indexPath.row]
        let sourceEvidence = pool.excerpts
            .filter { row.evidenceIDs.contains($0.id) }
            .map { "[" + $0.id + "] " + $0.text }
            .joined(separator: "\n\n")
        let editor = ImpressAIQuestionEditor(
            question: row.question, answer: row.answer, sourceEvidence: sourceEvidence
        ) { [weak self] question, answer in
            guard let self else { return }
            self.pool.candidates[indexPath.row].question = question
            self.pool.candidates[indexPath.row].answer = answer
            self.pool = ImpressAIQuestionValidator.audit(self.pool)
            self.persistCandidateEdits()
            self.tableView.reloadRows(at: [indexPath], with: .none)
            self.updateImportButton()
        }
        navigationController?.pushViewController(editor, animated: true)
    }
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: V3L("删除")) { [weak self] _, _, finish in
            guard let self else { finish(false); return }
            self.pool.candidates.remove(at: indexPath.row)
            self.pool = ImpressAIQuestionValidator.audit(self.pool)
            self.persistCandidateEdits()
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.updateImportButton()
            finish(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
    @objc private func confirmImport() {
        guard !committing else { return }
        pool = ImpressAIQuestionValidator.audit(pool)
        tableView.reloadData()
        do { _ = try ImpressAIQuestionValidator.validatedSelection(pool) }
        catch { showFailure(error); return }
        let count = pool.candidates.filter { $0.selected }.count
        let alert = UIAlertController(title: V3L("加入卡片集？"),
           message: "\(count) \(V3L("张问答卡片将进入 FSRS 复习。Obsidian 原文不会修改。"))",
           preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: V3L("确认加入"), style: .default) { [weak self] _ in
            self?.performImport()
        })
        present(alert, animated: true)
    }

    private func readLatest() async throws -> ImVaultRawDocument {
        try await withCheckedThrowingContinuation { continuation in
            ImVaultReadSync.shared.read(document.identity) { result in
                continuation.resume(with: result)
            }
        }
    }
    private func performImport() {
        guard !committing else { return }
        committing = true
        updateImportButton()
        Task {
            defer { committing = false; updateImportButton() }
            do {
                // Fail closed if Obsidian was edited since generation.
                let live = try await readLatest()
                guard live.digest == pool.source.documentSHA256,
                      live.identity == document.identity else {
                    throw ImVaultSyncFailure.conflict
                }
                let repo = try ImpressV3ReviewEnvironment.repository()
                var existing: [String] = []
                var offset = 0
                while offset < 20_000 {
                    let batch = try await repo.listManagedCards(matching: "", offset: offset, limit: 200)
                    existing += batch.map(\.question)
                    if batch.count < 200 { break }
                    offset += batch.count
                }
                // Database transaction remains the final duplicate authority.
                let checked = ImpressAIQuestionValidator.audit(pool, existingQuestions: existing)
                let selected = try ImpressAIQuestionValidator.validatedSelection(checked, existingQuestions: existing)
                let sourceKey = try ImpressBatchSourceKey.encode(document.identity)
                let now = Date()
                let calc = FSRS6ReviewCalculator()
                let entries = try selected.map { candidate -> (input: WCDBV3CardInput, initial: ReviewScheduleSnapshot) in
                    let input = WCDBV3CardInput(question: candidate.question,
                         answerText: candidate.answer, cardType: CardType.standard.rawValue,
                         sourceNotePath: sourceKey)
                    return (input: input, initial: try calc.newCardSnapshot(id: input.cardID, now: now))
                }
                try await repo.insertBatchCards(entries, now: now)
                // WCDB is already committed; cleanup failure must not misreport
                // the cards as unsaved. Any retained draft is still local only.
                try? ImVaultPrivateStore.deleteQuestionPool(identity: document.identity)
                let alert = UIAlertController(title: V3L("卡片已添加"),
                   message: "\(selected.count) \(V3L("张卡片已保存到 V3 卡片集。"))",
                   preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: V3L("完成"), style: .default) { [weak self] _ in
                    self?.navigationController?.popToRootViewController(animated: true)
                })
                present(alert, animated: true)
            } catch { showFailure(error) }
        }
    }
    private func showFailure(_ error: Error) {
        let alert = UIAlertController(title: V3L("无法保存卡片"),
            message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(alert, animated: true)
    }
}

@MainActor
private final class ImpressAIQuestionEditor: UIViewController {
    private let question = UITextView()
    private let answer = UITextView()
    private let evidence = UITextView()
    private let onSave: (String, String) -> Void
    init(question: String, answer: String, sourceEvidence: String,
         onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        self.question.text = question
        self.answer.text = answer
        self.evidence.text = sourceEvidence
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("编辑候选题")
        view.backgroundColor = ImpressV3Appearance.page
        let title1 = UILabel()
        title1.text = V3L("问题")
        let title2 = UILabel()
        title2.text = V3L("参考答案")
        let title3 = UILabel()
        title3.text = V3L("来源依据（只读）")
        for field in [question, answer] {
            field.font = ImpressV3Appearance.Typography.body
            field.backgroundColor = ImpressV3Appearance.surface
            field.textColor = ImpressV3Appearance.primaryText
            field.layer.cornerRadius = ImpressV3Appearance.Radius.field
            field.isScrollEnabled = true
            ImpressSpeechAccessory.install(on: field)
        }
        evidence.isEditable = false
        evidence.isSelectable = true
        evidence.font = ImpressV3Appearance.Typography.supporting
        evidence.textColor = ImpressV3Appearance.secondaryText
        evidence.backgroundColor = ImpressV3Appearance.surface
        evidence.layer.cornerRadius = ImpressV3Appearance.Radius.field
        let stack = UIStackView(arrangedSubviews: [title1, question, title2, answer, title3, evidence])
        stack.axis = .vertical
        stack.spacing = ImpressV3Appearance.Metrics.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
            question.heightAnchor.constraint(equalTo: answer.heightAnchor, multiplier: 0.55),
            evidence.heightAnchor.constraint(equalToConstant: 110)
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: V3L("保存"), style: .done, target: self, action: #selector(save))
    }
    @objc private func save() {
        onSave(question.text ?? "", answer.text ?? "")
        navigationController?.popViewController(animated: true)
    }
}
