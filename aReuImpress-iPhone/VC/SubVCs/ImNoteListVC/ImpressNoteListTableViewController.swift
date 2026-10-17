//
//  ImpressNoteListTableViewController.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 12/8/22.
//  fix 20230129合拼四大页面到Notes页,去掉侧滑(理由:耗时)
//  fix 20230131整合鸡汤页面(激励以适量为好)
//  fix 20230923整合Review页面+大量删减非刚需代码 (少即多),另外采取强制推送方案,即已设置了就不能取消,但可以重置
//  fix 20250110再次精简,只保留核心业务(显示+搜索),其余影响效率的逻辑去掉

import UIKit
import Combine
import ImpressReviewCore

extension ImPreChatListCell {
    func configure(with note: ImNoteModel) {
        questionLabel.text = note.mainTitle ?? "无标题"
        contentLabel.text = note.markdownText ?? "无内容"
        if let source = note.directoryPath, !source.isEmpty {
            sourceLabel.text = "目录: \(source)"
            sourceLabel.isHidden = false
        } else {
            sourceLabel.isHidden = true
        }

        // 显示状态指示器 - 可以根据笔记是否有内容或其他条件来设置
        let hasContent = !(note.markdownText?.isEmpty ?? true)
        if hasContent {
            statusIndicator.image = UIImage(systemName: "doc.text.fill")
            statusIndicator.tintColor = .systemBlue
        } else {
            statusIndicator.image = UIImage(systemName: "doc.text")
            statusIndicator.tintColor = .systemGray
        }
    }
}

enum NetActionType:String
{
    case allNoti = "已设定通知"
    case testAPI = "testAPI"
    case llm = "大模型/提示词"
}


class ImpressNoteListTableViewController: ImBaseViewController
{
    private var cancellables = Set<AnyCancellable>()
    
    let tableView = UITableView(frame: .zero, style: .plain)
    ///
    private var viewModel: ImNotesViewModelProtocol! = ImpressNotesViewModel()
    
    private let reuseID = ImPreChatListCell.reuseIdentifier
    // External Vault never merges into the legacy Note WCDB table.
    private var externalMode = false
    private var externalNotes: [ImVaultIndexNote] = []
    private var externalSearchText = ""
    private var externalLoading = false
    private var externalReadGate = ImVaultAsyncReadGate()
    private var externalError: String?
    private var visibleExternalNotes: [ImVaultIndexNote] {
        let query = externalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return externalNotes }
        return externalNotes.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.identity.relativePath.localizedCaseInsensitiveContains(query)
        }
    }
    
    
    private var selectedNoteID : Int?
    
    /// 默认为不可自动滑动到指定位置
    private var canScrollToSelect: Bool = false
    
    
    
    convenience init(noteID: Int)
    {
        self.init()
        self.selectedNoteID  = noteID
        // 允许自动滑动到指定位置
        self.canScrollToSelect = true
    }
    
    // MARK: - Function
    override func viewDidLoad()
    {
        super.viewDidLoad()
        initUISetting()
        NotificationCenter.default.addObserver(self,
             selector: #selector(handleVaultForeground(_:)),
             name: UIApplication.didBecomeActiveNotification, object: nil)
        setupBindings()
        // 底层两步实现,先从数据库获取原有笔记集,然后从obsidian文件夹批量获取笔记进行校验,最后更新数据并刷新页面
        // TODO: 更改路径读取即可
        refreshNotes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.largeTitleDisplayMode = .always
        if ImVaultReadOnlyProbe.shared.hasAuthorizedBookmark && !externalLoading {
            refreshNotes()
        }
    }
    
    /// 初始化UI
    private func initUISetting()
    {
        title = ImpressV3ReviewEnvironment.pilotEnabled ? "笔记" : imNotesTitle 
        view.backgroundColor = bgColor
//        navigationItem.largeTitleDisplayMode = .always
        searchControllerSetting()
        tableViewSetting()
        setupNavigationBarItems()
    }
    
    /// 设置导航栏按钮
    private func setupNavigationBarItems()
    {
        // R04.2: No legacy database-ID viewer in the V3 Notes tab.
        navigationItem.leftBarButtonItem = nil

        // P0-1: explicit read-only external Vault probe. The old importer
        // is still available only as a first-time, NON-overwriting local copy.
        let connectVault = UIAction(title: "选择 Obsidian Vault（只读）",
                                    image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
            self?.chooseReadOnlyVault()
        }
        let inspectSaved = UIAction(title: "验证已授权 Vault（只读）",
                                    image: UIImage(systemName: "checkmark.shield")) { [weak self] _ in
            self?.inspectSavedVault()
        }
        let disconnectVault = UIAction(title: "断开 Vault 授权（不删除文件）",
                                       image: UIImage(systemName: "xmark.shield")) { [weak self] _ in
            self?.confirmVaultDisconnect()
        }
        let vaultItem = UIBarButtonItem(image: UIImage(systemName: "folder"),
                                         style: .plain, target: nil, action: nil)
        vaultItem.menu = UIMenu(title: "Vault 安全访问 · P0", children: [
            connectVault, inspectSaved, disconnectVault
        ])
        navigationItem.rightBarButtonItem = vaultItem
    }
    
    // The picker grants scoped access; all file probes run off the main
    // thread. Both methods are READ-ONLY with respect to Obsidian.
    private func chooseReadOnlyVault() {
        ImVaultReadOnlyProbe.shared.chooseFolder(from: self) { [weak self] result in
            self?.showReadOnlyVaultResult(result)
        }
    }

    private func inspectSavedVault() {
        ImVaultReadOnlyProbe.shared.inspectSavedPermission { [weak self] result in
            self?.showReadOnlyVaultResult(result)
        }
    }

    private func confirmVaultDisconnect() {
        let alert = UIAlertController(
            title: "断开 Obsidian Vault 授权？",
            message: "只清除 Impress 保存的访问书签，不会删除、修改或移动任何 Obsidian 文件，也不会删除本地笔记镜像。",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "断开", style: .destructive) { _ in
            ImVaultReadOnlyProbe.shared.disconnectSavedPermission()
            self.externalMode = false
            self.externalNotes = []
            self.externalSearchText = ""
            self.externalError = nil
            self.refreshNotes()
        })
        present(alert, animated: true)
    }

    private func showReadOnlyVaultResult(_ result: Result<ImVaultReadOnlyReport, Error>) {
        let alert: UIAlertController
        switch result {
        case let .success(report):
            self.externalMode = true
            self.refreshNotes()
            let sample = report.sampleRelativePaths.isEmpty
                ? "无 Markdown 样本。请确认所选目录。"
                : report.sampleRelativePaths.joined(separator: "\n")
            let text = "Vault: \(report.name)\nMarkdown: \(report.markdownCount) 篇\(report.wasTruncated ? "（扫描上限）" : "")\n样本读取: \(report.sampleBytesRead) bytes\n授权恢复: \(report.restoredFromBookmark ? "已验证" : "首次连接")\n\n\(sample)\n\n仅校验授权和读取，未写入任何 Obsidian 文件。真实双向同步尚未启用。"
            alert = UIAlertController(title: "Vault 只读验证完成",
                                      message: text, preferredStyle: .alert)
        case let .failure(error):
            if let vaultError = error as? ImVaultReadOnlyError, case .noFolder = vaultError { return }
            alert = UIAlertController(title: "Vault 只读验证未通过",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        }
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    /// 从iCloud Drive导入
    @objc private func importFromiCloudDrive()
    {
        // 显示确认提示
        ImAlertController.alert(
            message: "只会在 ImpressVault 不存在时首次复制。不会覆盖已有笔记，也不是双向同步。是否继续？",
            buttons: alertDescription) { [weak self] result in
            if case .ok = result {
                self?.performiCloudImport()
            }
        }
    }
    
    /// 执行iCloud导入
    private func performiCloudImport()
    {
        loadShare.show()
        ImiCloudImportManager.shared.performManualImport(from: self) { [weak self] error in
            DispatchQueue.main.async {
                loadShare.hide()
                if let error = error {
                    ImAlertController.warningAlert(error.localizedDescription)
                } else {
                    // 导入成功，刷新笔记列表
                    self?.refreshNotes()
                    ImAlertController.alert(message: "笔记导入成功")
                }
            }
        }
    }
    
    @objc private func handleVaultForeground(_ notification: Notification) {
        // A covered/hidden Notes view should not perform a large Vault scan.
        guard view.window != nil else { return }
        refreshNotes()
    }

    /// 刷新笔记列表
    @objc func refreshNotes()
    {
        if let vaultID = ImVaultReadOnlyProbe.shared.authorizedVaultID {
            externalMode = true
            // Reconnecting a different Vault must invalidate in-flight
            // asynchronous reads from the previously authorized directory.
            // Otherwise a late callback can show private titles from Vault A
            // while the user is connected to Vault B.
            if externalReadGate.changeSource(to: vaultID) {
                externalLoading = false
                externalNotes = []
                externalError = nil
            }
            guard !externalLoading else { return }
            let token = externalReadGate.begin(for: vaultID)
            externalLoading = true
            ImVaultReadSync.shared.refresh { [weak self] result in
                guard let self = self, self.externalMode,
                      ImVaultReadOnlyProbe.shared.authorizedVaultID == vaultID,
                      self.externalReadGate.accepts(token) else { return }
                self.externalLoading = false
                switch result {
                case let .success(index):
                    self.externalNotes = index.notes
                    self.externalError = nil
                case let .failure(error):
                    // Never silently present old WCDB data as live Vault data.
                    self.externalNotes = []
                    self.externalError = error.localizedDescription
                }
                self.tableView.refreshControl?.endRefreshing()
                self.tableView.reloadData()
                self.updateVaultEmptyState()
            }
        } else {
            // Invalidate callbacks from a previous authorization/source.
            externalReadGate.changeSource(to: nil)
            externalLoading = false
            externalMode = false
            externalNotes = []
            externalError = nil
            updateVaultEmptyState()
            tableView.refreshControl?.endRefreshing()
            viewModel.fetchNotes(by: self)
        }
    }

    private func updateVaultEmptyState() {
        guard externalMode else { tableView.backgroundView = nil; return }
        if !visibleExternalNotes.isEmpty { tableView.backgroundView = nil; return }
        let message = UILabel()
        message.text = externalError ??
            (externalLoading ? "正在安全读取 Vault…" : "此 Vault 没有可读取的 Markdown 笔记")
        message.numberOfLines = 0
        message.textColor = .secondaryLabel
        message.textAlignment = .center
        message.font = UIFont.preferredFont(forTextStyle: .subheadline)
        tableView.backgroundView = message
    }
}


// MARK: - seachBarConfig
extension ImpressNoteListTableViewController: UISearchBarDelegate
{
    private func searchControllerSetting()
    {
        let controller = UISearchController.init(searchResultsController: nil)
        controller.searchBar.placeholder = impressPageForNotesSearchBarDes
        controller.searchBar.delegate = self
        controller.searchBar.tintColor = titleColor
        controller.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    /// 筛选搜索Action
    private func searchDBByText(_ text:String? = nil)
    {
        if externalMode {
            externalSearchText = text ?? ""
            tableView.reloadData()
            updateVaultEmptyState()
            return
        }
        guard let t = text, t.count > 0 else {
            viewModel.updateStatusInFliter()
            return
        }
        viewModel.predicateNoteSeriesDatas(filtterText: t)
    }
    
    func searchBar(_ searchBar: UISearchBar,
                   textDidChange searchText: String)
    {
        guard let text = searchBar.text else { return }
        searchDBByText(text)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar)
    {
        searchDBByText()
    }
}

// MARK: - TableView + UITableViewDelegate
extension ImpressNoteListTableViewController:UITableViewDataSource,UITableViewDelegate
{
    private func scrollToSelectedNoteIfApplicable()
    {
        guard let selectedID = selectedNoteID ,
              let indexPath = viewModel.indexPath(for: selectedID) else {
            return
        }
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    private func tableViewSetting()
    {
        view.addSubview(tableView)
        tableView.backgroundColor = bgColor
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.showsVerticalScrollIndicator = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 65
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            tableView.leftAnchor.constraint(equalTo: safeArea.leftAnchor),
            tableView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            tableView.rightAnchor.constraint(equalTo: safeArea.rightAnchor)
        ])
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ImPreChatListCell.self,
                           forCellReuseIdentifier: reuseID)
        tableView.tableFooterView = UIView(frame: .zero)
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshNotes), for: .valueChanged)
        tableView.refreshControl = refresh
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // External Vault is one continuous list, not one giant rounded
        // section for every Markdown file. Legacy section identities remain.
        externalMode ? 1 : viewModel.currentNotesCount
    }

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        externalMode ? visibleExternalNotes.count : 1
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        externalMode ? "当前来源 · Obsidian（只读）" : nil
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if externalMode {
            guard visibleExternalNotes.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let note = visibleExternalNotes[indexPath.row]
            let identifier = "vault-note-row"
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
            var content = UIListContentConfiguration.subtitleCell()
            content.text = note.title
            content.secondaryText = note.identity.relativePath
            content.image = UIImage(systemName: "doc.text")
            content.imageProperties.tintColor = .systemBlue
            content.textProperties.numberOfLines = 2
            content.secondaryTextProperties.numberOfLines = 2
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseID,
                   for: indexPath) as? ImPreChatListCell else {
            return UITableViewCell()
        }
        if let note = viewModel.getCurrentNote(indexPath: indexPath) {
            cell.configure(with: note)
        }
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: false)
        if externalMode {
            guard visibleExternalNotes.indices.contains(indexPath.row) else { return }
            let item = visibleExternalNotes[indexPath.row]
            ImVaultReadSync.shared.read(item.identity) { [weak self] result in
                guard let self = self,
                      self.externalMode,
                      ImVaultReadOnlyProbe.shared.authorizedVaultID ==
                          item.identity.vaultID else { return }
                switch result {
                case let .success(source):
                    self.navigationController?.pushViewController(
                        ImVaultDocumentController(document: source), animated: true)
                case let .failure(error):
                    let alert = UIAlertController(title: "无法读取源笔记",
                        message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
            return
        }
        let note = viewModel.getCurrentNote(indexPath: indexPath)
        let mdVC = ImMarkdownViewController.init(note: note)
        navigationController?.pushViewController(mdVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        // P0-0: a swipe must NEVER delete the shared-note index or source file.
        // Future deletion requires a separate backed-up and confirmed workflow.
        return nil
    }

    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration?
    {
        if externalMode { return nil }
        return UIContextMenuConfiguration.init(identifier: nil) { () -> UIViewController? in
            guard let cell = tableView.cellForRow(at: indexPath) else { return nil }
            let copiedView = cell.snapshotView(afterScreenUpdates: false)
            copiedView?.frame = CGRect(origin: .zero, size: cell.frame.size)
            copiedView?.backgroundColor = tableViewBGColor
            let previewVC = UIViewController()
            previewVC.view.backgroundColor = .clear
            previewVC.view.addSubview(copiedView!)
            previewVC.preferredContentSize = cell.frame.size
            return previewVC
        } actionProvider: { [weak self] _ in
            return self?.makeContextMenu(for: indexPath)
        }
    }
    
    /// 跳转AI问答
    /// - Parameters:
    ///   - isPrompt: <#isPrompt description#>
    ///   - content: <#content description#>
    func pushInjectContent(isPrompt:Bool,_ note: ImNoteModel)
    {
        // TODO: 重新实现注入

    }
    
    // 创建上下文菜单
    private func makeContextMenu(for indexPath: IndexPath) -> UIMenu
    {
        guard let note = viewModel.getCurrentNote(indexPath: indexPath) else {return UIMenu()}
        let contentAction = UIAction(title: "注入:默认内容") {[weak self] _ in
            self?.pushInjectContent(isPrompt: false,note)
        }
        let contentPromptAction = UIAction(title: "注入:默认内容+提示词") { [weak self] _ in
            self?.pushInjectContent(isPrompt: true, note)
        }
        //
        let getContentAction = UIAction(title: "获取当前笔记内容") { [weak self] _ in
//            if let chat = self?.viewModel.getQuestionFromCurrentNote(indexPath: indexPath){
//                self?.chatResult?(chat,.note)
//            }
        }
        return UIMenu(title:"", children: [contentAction,
                                           contentPromptAction,
                                           getContentAction])
    }
}

// MARK: - 绑定事件逻辑业务
extension ImpressNoteListTableViewController
{
    private func setupBindings()
    {
        // 订阅数据源和过滤状态的变化，用于刷新列表
        viewModel.notesPublisher
            .combineLatest(viewModel.filteredNotesPublisher, viewModel.isFilteringPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                guard let self = self else { return }
                self.tableView.reloadData()
                // 确保自动滚动逻辑只在需要时执行一次
                if self.canScrollToSelect {
                    self.canScrollToSelect = false
                    self.scrollToSelectedNoteIfApplicable()
                }
            }
            .store(in: &cancellables)

        // 订阅一次性动作事件，如加载、提示、删除等
        viewModel.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .isLoading(let isLoading):
                    isLoading ? loadShare.show() : loadShare.hide()
                case .success(let content):
                    ImAlertController.alert(message: content)
                case .errorOccurred(let error):
                    ImAlertController.warningAlert(error.localizedDescription)
                case .protocolSpecific(.note(.delete(let indexPath))):
                    self.tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
