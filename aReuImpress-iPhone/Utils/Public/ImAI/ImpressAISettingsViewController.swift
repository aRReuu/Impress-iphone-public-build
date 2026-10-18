import UIKit
import ImpressReviewCore

// Native settings: one provider may have many independent connections/keys and
// each connection may have several models. No API secret goes into a cell subtitle.
@MainActor
final class ImpressAISettingsViewController: UITableViewController {
    private let tasks: [ImpressAITask] = [.questionGeneration, .knowledgeSynthesis, .conversation]

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("AI 服务")
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.rowHeight = UITableView.automaticDimension
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addConnection))
        navigationItem.rightBarButtonItem?.accessibilityLabel = V3L("添加 API 连接")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return ImpressAIConfigStore.shared.registry.connections.count
        case 1: return tasks.count
        default: return 1
        }
    }
    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        [V3L("API 连接"), V3L("业务默认模型"), V3L("隐私与数据边界")][section]
    }
    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return V3L("每个连接独立保存 API Key，可添加多个服务商和模型。")
        case 1: return V3L("指定笔记出题需要先测试模型 JSON 能力。不会自动跨服务商发送笔记。")
        default: return V3L("仅在你明确确认生成时发送选定的笔记内容；API Key 留在本机 Keychain。")
        }
    }

    private func taskTitle(_ task: ImpressAITask) -> String {
        switch task {
        case .questionGeneration: return V3L("指定笔记出题")
        case .knowledgeSynthesis: return V3L("知识重构（尚未启用）")
        case .conversation: return V3L("原生对话（尚未启用）")
        }
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        let config = ImpressAIConfigStore.shared.registry
        switch indexPath.section {
        case 0:
            let c = config.connections[indexPath.row]
            let count = config.models.filter { $0.connectionID == c.id }.count
            content.text = c.title
            content.secondaryText = "\(c.provider.rawValue) · \(count) \(V3L("个模型"))"
            content.image = UIImage(systemName: "server.rack")
        case 1:
            let task = tasks[indexPath.row]
            content.text = taskTitle(task)
            if let route = config.routes.first(where: { $0.task == task }),
               let model = config.models.first(where: { $0.id == route.primaryModelID }),
               let connection = config.connections.first(where: { $0.id == model.connectionID }) {
                content.secondaryText = connection.title + " · " + model.identifier
            } else { content.secondaryText = V3L("未配置") }
            content.image = UIImage(systemName: "arrow.triangle.branch")
        default:
            content.text = V3L("数据上传规则")
            content.secondaryText = V3L("按需授权、仅上传选定文档、不会修改原始 Vault")
            content.image = UIImage(systemName: "lock.shield")
        }
        content.textProperties.font = ImpressV3Appearance.Typography.body
        content.secondaryTextProperties.font = ImpressV3Appearance.Typography.supporting
        content.secondaryTextProperties.numberOfLines = 3
        cell.contentConfiguration = content
        ImpressV3Appearance.styleGroupedCell(cell)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            let c = ImpressAIConfigStore.shared.registry.connections[indexPath.row]
            navigationController?.pushViewController(ImpressAIConnectionEditor(connectionID: c.id), animated: true)
        case 1:
            navigationController?.pushViewController(
                ImpressAIModelChooser(task: tasks[indexPath.row]), animated: true)
        default:
            let alert = UIAlertController(title: V3L("数据上传规则"),
                message: V3L("云端模型会接收你明确选择的笔记片段。服务商可能根据各自政策处理请求；不会默认上传整个 Obsidian Vault。所有自动写回仍被生产安全门禁关闭。"),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: V3L("知道了"), style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func addConnection() {
        let sheet = UIAlertController(title: V3L("选择服务商"), message: nil, preferredStyle: .actionSheet)
        let presets: [(ImpressAIProvider, ImpressAIProtocol, String)] = [
            (.openAI, .responses, "https://api.openai.com/v1"),
            (.deepSeek, .chatCompletions, "https://api.deepseek.com"),
            (.anthropic, .anthropicMessages, "https://api.anthropic.com/v1"),
            (.gemini, .geminiGenerateContent, "https://generativelanguage.googleapis.com/v1beta"),
            (.custom, .chatCompletions, "https://api.example.com/v1")
        ]
        for (provider, wire, url) in presets {
            sheet.addAction(UIAlertAction(title: provider.rawValue, style: .default) { [weak self] _ in
                guard let self, let endpoint = URL(string: url) else { return }
                let profile = ImpressAIConnection(title: provider.rawValue, provider: provider,
                                                  apiProtocol: wire, baseURL: endpoint)
                do {
                    try ImpressAIConfigStore.shared.update { $0.connections.append(profile) }
                    self.navigationController?.pushViewController(
                        ImpressAIConnectionEditor(connectionID: profile.id), animated: true)
                } catch { self.showFailure(error) }
            })
        }
        sheet.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }

    private func showFailure(_ error: Error) {
        let alert = UIAlertController(title: V3L("操作失败"),
              message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(alert, animated: true)
    }
}

@MainActor
final class ImpressAIConnectionEditor: UITableViewController {
    private let connectionID: UUID
    init(connectionID: UUID) {
        self.connectionID = connectionID
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    private var connection: ImpressAIConnection? {
        ImpressAIConfigStore.shared.registry.connections.first(where: { $0.id == connectionID })
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("API 连接")
        tableView.backgroundColor = ImpressV3Appearance.page
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 5 : 1
    }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let c = connection
        let labels = [V3L("连接名称"), V3L("服务商 / 协议"),
                      "Base URL", "API Key", V3L("模型列表")]
        cell.textLabel?.text = indexPath.section == 0 ? labels[indexPath.row] : V3L("删除连接")
        cell.textLabel?.font = ImpressV3Appearance.Typography.body
        cell.textLabel?.textColor = indexPath.section == 1
            ? ImpressV3Appearance.secondaryText : ImpressV3Appearance.primaryText
        if indexPath.section == 0 {
            let models = ImpressAIConfigStore.shared.registry.models
            let values = [c?.title ?? "", (c?.provider.rawValue ?? "") + " / " + (c?.apiProtocol.rawValue ?? ""),
                          c?.baseURL.host ?? "", c?.credentialID == nil ? V3L("未保存") : V3L("已保存"),
                          "\(models.filter { $0.connectionID == connectionID }.count)"]
            cell.detailTextLabel?.text = values[indexPath.row]
            cell.accessoryType = .disclosureIndicator
        }
        ImpressV3Appearance.styleGroupedCell(cell)
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 { confirmDelete(); return }
        switch indexPath.row {
        case 0: editText(title: V3L("连接名称"), secure: false, value: connection?.title ?? "") { [weak self] value in
            self?.edit { $0.title = value }
        }
        case 1: chooseProtocol()
        case 2: editText(title: "Base URL", secure: false,
                         value: connection?.baseURL.absoluteString ?? "") { [weak self] value in
            guard let url = URL(string: value) else { self?.showError(ImpressAIServiceError.invalidURL); return }
            self?.edit { $0.baseURL = url }
        }
        case 3: editText(title: "API Key", secure: true, value: "") { [weak self] value in
            guard let self else { return }
            do {
                guard let current = self.connection else { throw ImpressAIServiceError.configuration }
                let id = current.credentialID ?? UUID()
                try ImpressAIKeychain.write(value, id: id)
                do { try ImpressAIConfigStore.shared.update { reg in
                    guard let index = reg.connections.firstIndex(where: { $0.id == self.connectionID }) else {
                        throw ImpressAIServiceError.configuration
                    }
                    reg.connections[index].credentialID = id
                } } catch {
                    if current.credentialID == nil { ImpressAIKeychain.delete(id: id) }
                    throw error
                }
                self.tableView.reloadData()
            } catch { self.showError(error) }
        }
        case 4:
            navigationController?.pushViewController(
                ImpressAIModelsViewController(connectionID: connectionID), animated: true)
        default: break
        }
    }
    private func edit(_ modify: (inout ImpressAIConnection) -> Void) {
        do {
            try ImpressAIConfigStore.shared.update { reg in
                guard let index = reg.connections.firstIndex(where: { $0.id == self.connectionID }) else {
                    throw ImpressAIServiceError.configuration
                }
                modify(&reg.connections[index])
            }
            tableView.reloadData()
        } catch { showError(error) }
    }
    private func editText(title: String, secure: Bool, value: String,
                          onSave: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.text = value
            $0.isSecureTextEntry = secure
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: V3L("保存"), style: .default) { _ in
            onSave(alert.textFields?.first?.text ?? "")
        })
        present(alert, animated: true)
    }
    private func chooseProtocol() {
        guard let c = connection else { return }
        let sheet = UIAlertController(title: V3L("协议类型"), message: nil, preferredStyle: .actionSheet)
        for wire in ImpressAIProtocol.allCases {
            // Known providers have one canonical protocol, except OpenAI.
            let allowed: Bool
            switch c.provider {
            case .openAI: allowed = wire == .responses || wire == .chatCompletions
            case .deepSeek: allowed = wire == .chatCompletions
            case .anthropic: allowed = wire == .anthropicMessages
            case .gemini: allowed = wire == .geminiGenerateContent
            case .custom: allowed = true
            }
            guard allowed else { continue }
            sheet.addAction(UIAlertAction(title: wire.rawValue, style: .default) { [weak self] _ in
                self?.edit { $0.apiProtocol = wire }
            })
        }
        sheet.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        sheet.popoverPresentationController?.sourceView = tableView
        sheet.popoverPresentationController?.sourceRect = tableView.bounds
        present(sheet, animated: true)
    }
    private func confirmDelete() {
        let a = UIAlertController(title: V3L("删除 API 连接？"),
                      message: V3L("连接、其模型和业务路由将被移除；Keychain 密钥也会删除。"),
                      preferredStyle: .alert)
        a.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        a.addAction(UIAlertAction(title: V3L("删除"), style: .destructive) { [weak self] _ in
            guard let self, let c = self.connection else { return }
            do {
                try ImpressAIConfigStore.shared.update { reg in
                    let oldIDs = Set(reg.models.filter { $0.connectionID == self.connectionID }.map(\.id))
                    reg.models.removeAll { oldIDs.contains($0.id) }
                    reg.routes.removeAll {
                        oldIDs.contains($0.primaryModelID) || ($0.fallbackModelID.map(oldIDs.contains) ?? false)
                    }
                    reg.connections.removeAll { $0.id == self.connectionID }
                }
                ImpressAIKeychain.delete(id: c.credentialID)
                self.navigationController?.popViewController(animated: true)
            } catch { self.showError(error) }
        })
        present(a, animated: true)
    }
    private func showError(_ error: Error) {
        let a = UIAlertController(title: V3L("操作失败"), message: error.localizedDescription,
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(a, animated: true)
    }
}

@MainActor
final class ImpressAIModelsViewController: UITableViewController {
    private let connectionID: UUID
    init(connectionID: UUID) { self.connectionID = connectionID; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    private var connection: ImpressAIConnection? {
        ImpressAIConfigStore.shared.registry.connections.first { $0.id == connectionID }
    }
    private var models: [ImpressAIModel] {
        ImpressAIConfigStore.shared.registry.models.filter { $0.connectionID == connectionID }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("模型列表")
        tableView.backgroundColor = ImpressV3Appearance.page
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addManual)),
            UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain,
                            target: self, action: #selector(refreshModels))
        ]
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { models.count }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let m = models[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var ui = UIListContentConfiguration.subtitleCell()
        ui.text = m.identifier
        ui.secondaryText = m.jsonVerified ? V3L("JSON 测试已通过") : V3L("尚未验证 JSON 输出")
        ui.image = UIImage(systemName: m.jsonVerified ? "checkmark.shield" : "questionmark.circle")
        cell.contentConfiguration = ui
        ImpressV3Appearance.styleGroupedCell(cell)
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = models[indexPath.row]
        let a = UIAlertController(title: model.identifier, message: nil, preferredStyle: .actionSheet)
        a.addAction(UIAlertAction(title: V3L("测试 JSON 输出"), style: .default) { [weak self] _ in
            self?.testModel(model)
        })
        a.addAction(UIAlertAction(title: V3L("作为出题模型"), style: .default) { [weak self] _ in
            self?.setRoute(.questionGeneration, modelID: model.id)
        })
        a.addAction(UIAlertAction(title: V3L("作为对话模型"), style: .default) { [weak self] _ in
            self?.setRoute(.conversation, modelID: model.id)
        })
        a.addAction(UIAlertAction(title: V3L("删除模型"), style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                try ImpressAIConfigStore.shared.update { reg in
                    reg.routes.removeAll {
                        $0.primaryModelID == model.id || $0.fallbackModelID == model.id
                    }
                    reg.models.removeAll { $0.id == model.id }
                }
                self.tableView.reloadData()
            } catch { self.error(error) }
        })
        a.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        a.popoverPresentationController?.sourceView = tableView
        a.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
        present(a, animated: true)
    }
    @objc private func addManual() {
        let a = UIAlertController(title: V3L("添加模型 ID"), message: nil, preferredStyle: .alert)
        a.addTextField { $0.autocapitalizationType = .none; $0.autocorrectionType = .no }
        a.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        a.addAction(UIAlertAction(title: V3L("添加"), style: .default) { [weak self] _ in
            self?.addModelID(a.textFields?.first?.text ?? "")
        })
        present(a, animated: true)
    }
    private func addModelID(_ id: String) {
        do {
            let model = ImpressAIModel(connectionID: connectionID,
                    identifier: id.trimmingCharacters(in: .whitespacesAndNewlines))
            try ImpressAIConfigStore.shared.update { $0.models.append(model) }
            tableView.reloadData()
        } catch { error(error) }
    }
    @objc private func refreshModels() {
        guard let c = connection else { return }
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
        Task {
            do {
                let names = try await ImpressAIHTTPClient.shared.listModels(connection: c)
                try ImpressAIConfigStore.shared.update { registry in
                    let existing = Set(registry.models.filter { $0.connectionID == self.connectionID }
                        .map { $0.identifier.lowercased() })
                    for id in names where !existing.contains(id.lowercased()) {
                        registry.models.append(ImpressAIModel(connectionID: self.connectionID, identifier: id))
                    }
                }
                tableView.reloadData()
            } catch { error(error) }
            navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
        }
    }
    private func testModel(_ model: ImpressAIModel) {
        guard let c = connection else { return }
        Task {
            do {
                guard try await ImpressAIHTTPClient.shared.probeJSON(connection: c, model: model) else {
                    throw ImpressAIServiceError.response
                }
                try ImpressAIConfigStore.shared.update { reg in
                    guard let i = reg.models.firstIndex(where: { $0.id == model.id }) else { return }
                    reg.models[i].jsonVerified = true
                }
                tableView.reloadData()
            } catch { error(error) }
        }
    }
    private func setRoute(_ task: ImpressAITask, modelID: UUID) {
        do {
            try ImpressAIConfigStore.shared.update { reg in
                reg.routes.removeAll { $0.task == task }
                reg.routes.append(ImpressAIRoute(task: task, primaryModelID: modelID))
            }
            let a = UIAlertController(title: V3L("已选择默认模型"), message: nil, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: V3L("确定"), style: .default))
            present(a, animated: true)
        } catch { error(error) }
    }
    private func error(_ error: Error) {
        let a = UIAlertController(title: V3L("操作失败"), message: error.localizedDescription,
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(a, animated: true)
    }
}

@MainActor
final class ImpressAIModelChooser: UITableViewController {
    private let task: ImpressAITask
    init(task: ImpressAITask) { self.task = task; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    private var models: [ImpressAIModel] { ImpressAIConfigStore.shared.registry.models }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("选择业务模型")
        tableView.backgroundColor = ImpressV3Appearance.page
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { models.count }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let m = models[indexPath.row]
        let registry = ImpressAIConfigStore.shared.registry
        let c = registry.connections.first { $0.id == m.connectionID }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var ui = UIListContentConfiguration.subtitleCell()
        ui.text = m.identifier
        ui.secondaryText = (c?.title ?? "") + " · " +
            (m.jsonVerified ? V3L("JSON 已验证") : V3L("未测试"))
        cell.contentConfiguration = ui
        cell.accessoryType = registry.routes.first { $0.task == task }?.primaryModelID == m.id
            ? .checkmark : .none
        ImpressV3Appearance.styleGroupedCell(cell)
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let m = models[indexPath.row]
        if task == .knowledgeSynthesis && !m.toolsVerified {
            let alert = UIAlertController(title: V3L("该功能尚未开放"),
                   message: V3L("知识重构需要单独的工具调用及 Vault 写回安全验收。"),
                   preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
            present(alert, animated: true)
            return
        }
        do {
            try ImpressAIConfigStore.shared.update { reg in
                reg.routes.removeAll { $0.task == self.task }
                reg.routes.append(ImpressAIRoute(task: self.task, primaryModelID: m.id))
            }
            navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(title: V3L("选择失败"),
                       message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
            present(alert, animated: true)
        }
    }
}
