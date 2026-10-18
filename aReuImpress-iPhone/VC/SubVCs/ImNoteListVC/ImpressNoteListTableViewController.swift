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

enum ImVaultListPresentation {
    static let pageSize = 120

    static func folders(in notes: [ImVaultIndexNote]) -> [String] {
        var paths = Set<String>()
        for note in notes {
            let components = note.identity.relativePath.split(separator: "/")
            guard components.count > 1 else { continue }
            for length in 1..<components.count {
                paths.insert(components.prefix(length).joined(separator: "/"))
            }
        }
        return paths.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func matched(_ notes: [ImVaultIndexNote],
                        query: String, folder: String?) -> [ImVaultIndexNote] {
        let searched = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            let path = note.identity.relativePath
            if let folder, !path.hasPrefix(folder + "/") { return false }
            return searched.isEmpty || note.title.localizedCaseInsensitiveContains(searched) ||
                path.localizedCaseInsensitiveContains(searched)
        }
    }

    static func page(_ notes: [ImVaultIndexNote], limit: Int) -> [ImVaultIndexNote] {
        Array(notes.prefix(max(0, limit)))
    }
}

@MainActor
private final class ImVaultFolderPickerViewController:
    UITableViewController, UISearchResultsUpdating {
    private let folders: [String]
    private var filteredFolders: [String]
    private let onChoose: (String?) -> Void

    init(folders: [String], onChoose: @escaping (String?) -> Void) {
        self.folders = folders
        self.filteredFolders = folders
        self.onChoose = onChoose
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("Use init(folders:onChoose:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "按文件夹浏览"
        navigationItem.largeTitleDisplayMode = .never
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "搜索相对路径"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.trimmingCharacters(
            in: .whitespacesAndNewlines) ?? ""
        filteredFolders = query.isEmpty ? folders : folders.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        filteredFolders.count + 1
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "folder-path")
            ?? UITableViewCell(style: .default, reuseIdentifier: "folder-path")
        var configuration = UIListContentConfiguration.cell()
        configuration.text = indexPath.row == 0 ? "全部文档" : filteredFolders[indexPath.row - 1]
        configuration.textProperties.numberOfLines = 2
        configuration.image = UIImage(systemName: indexPath.row == 0
                                      ? "square.grid.2x2" : "folder")
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        onChoose(indexPath.row == 0 ? nil : filteredFolders[indexPath.row - 1])
        navigationController?.popViewController(animated: true)
    }
}

class ImpressNoteListTableViewController: ImBaseViewController
{
    private var cancellables = Set<AnyCancellable>()
    
    let tableView = UITableView(frame: .zero, style: .plain)
    ///
    private var viewModel: ImNotesViewModelProtocol! = ImpressNotesViewModel()
    
    private let reuseID = "impress-note-native-cell"
    // External Vault never merges into the legacy Note WCDB table.
    private var externalMode = true
    private var externalNotes: [ImVaultIndexNote] = []
    private var externalSearchText = ""
    private var selectedVaultFolder: String?
    private var visibleExternalNotes: [ImVaultIndexNote] = []
    private var matchedExternalCount = 0
    private var externalVisibleLimit = ImVaultListPresentation.pageSize
    private var externalLoading = false
    private var showingCachedIndex = false
    private var showingPartialIndex = false
    private var externalReadGate = ImVaultAsyncReadGate()
    private var externalError: String?

    private var hasMoreExternalNotes: Bool {
        visibleExternalNotes.count < matchedExternalCount
    }

    private func rebuildExternalRows() {
        let matching = ImVaultListPresentation.matched(
            externalNotes, query: externalSearchText, folder: selectedVaultFolder)
        matchedExternalCount = matching.count
        visibleExternalNotes = ImVaultListPresentation.page(
            matching, limit: externalVisibleLimit)
    }

    private func showVaultFolderPicker() {
        let paths = ImVaultListPresentation.folders(in: externalNotes)
        let picker = ImVaultFolderPickerViewController(folders: paths) { [weak self] folder in
            guard let self else { return }
            self.selectedVaultFolder = folder
            self.externalVisibleLimit = ImVaultListPresentation.pageSize
            self.rebuildExternalRows()
            self.tableView.reloadData()
            self.updateVaultEmptyState()
        }
        navigationController?.pushViewController(picker, animated: true)
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
        title = "笔记"
        view.backgroundColor = ImpressV3ReviewEnvironment.pilotEnabled
            ? ImpressV3Appearance.page : bgColor
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
        let browseFolders = UIAction(title: "按文件夹浏览",
                                     image: UIImage(systemName: "folder.fill")) { [weak self] _ in
            self?.showVaultFolderPicker()
        }
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
        vaultItem.menu = UIMenu(title: "Vault · 只读", children: [
            browseFolders, connectVault, inspectSaved, disconnectVault
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
            self.externalMode = true
            self.externalNotes = []
            self.externalSearchText = ""
            self.selectedVaultFolder = nil
            self.externalVisibleLimit = ImVaultListPresentation.pageSize
            self.showingCachedIndex = false
            self.showingPartialIndex = false
            self.externalError = nil
            self.rebuildExternalRows()
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
            if externalReadGate.changeSource(to: vaultID) {
                externalLoading = false
                externalNotes = []
                selectedVaultFolder = nil
                externalVisibleLimit = ImVaultListPresentation.pageSize
                showingCachedIndex = false
                showingPartialIndex = false
                externalError = nil
                rebuildExternalRows()
            }
            guard !externalLoading else { return }
            let token = externalReadGate.begin(for: vaultID)
            externalLoading = true
            if externalNotes.isEmpty {
                ImVaultReadSync.shared.cachedIndex { [weak self] result in
                    guard let self, self.externalLoading, self.externalNotes.isEmpty,
                          ImVaultReadOnlyProbe.shared.authorizedVaultID == vaultID,
                          self.externalReadGate.accepts(token) else { return }
                    if case let .success(cached) = result, !cached.isEmpty {
                        self.externalNotes = cached
                        self.showingCachedIndex = true
                        self.rebuildExternalRows()
                        self.tableView.reloadData()
                        self.updateVaultEmptyState()
                    }
                }
            }
            ImVaultReadSync.shared.refresh(progress: { [weak self] batch in
                guard let self, self.externalLoading, !self.showingCachedIndex,
                      ImVaultReadOnlyProbe.shared.authorizedVaultID == vaultID,
                      self.externalReadGate.accepts(token) else { return }
                guard self.externalNotes.isEmpty || self.showingPartialIndex else { return }
                let remaining = max(0, 600 - self.externalNotes.count)
                guard remaining > 0 else { return }
                // A bounded, explicitly provisional preview; the full index
                // is published only when provider enumeration fully succeeds.
                self.externalNotes.append(contentsOf: batch.prefix(remaining))
                self.showingPartialIndex = true
                self.rebuildExternalRows()
                self.tableView.reloadData()
                self.updateVaultEmptyState()
            }) { [weak self] result in
                guard let self, self.externalMode,
                      ImVaultReadOnlyProbe.shared.authorizedVaultID == vaultID,
                      self.externalReadGate.accepts(token) else { return }
                self.externalLoading = false
                self.showingCachedIndex = false
                self.showingPartialIndex = false
                switch result {
                case let .success(index):
                    self.externalNotes = index.notes
                    self.externalError = nil
                case let .failure(error):
                    // No automatic fallback to retired local WCDB notes.
                    self.externalNotes = []
                    self.externalError = error.localizedDescription
                }
                self.rebuildExternalRows()
                self.tableView.refreshControl?.endRefreshing()
                self.tableView.reloadData()
                self.updateVaultEmptyState()
            }
        } else {
            externalReadGate.changeSource(to: nil)
            externalLoading = false
            externalMode = true
            externalNotes = []
            selectedVaultFolder = nil
            showingCachedIndex = false
            showingPartialIndex = false
            externalVisibleLimit = ImVaultListPresentation.pageSize
            externalError = nil
            rebuildExternalRows()
            updateVaultEmptyState()
            tableView.refreshControl?.endRefreshing()
            tableView.reloadData()
        }
    }

    private func updateVaultEmptyState() {
        guard externalMode else { tableView.backgroundView = nil; return }
        if !visibleExternalNotes.isEmpty { tableView.backgroundView = nil; return }
        let container = UIView()
        let contents = UIStackView()
        contents.axis = .vertical
        contents.alignment = .center
        contents.spacing = 16
        contents.translatesAutoresizingMaskIntoConstraints = false
        let message = UILabel()
        message.text = externalError ??
            (externalLoading ? "正在分批读取 Obsidian 文档…" :
             ImVaultReadOnlyProbe.shared.hasAuthorizedBookmark
                ? "此位置没有可读取的 Markdown 文档"
                : "连接 Obsidian Vault 后查看笔记")
        message.numberOfLines = 0
        message.textColor = ImpressV3Appearance.secondaryText
        message.textAlignment = .center
        message.font = ImpressV3Appearance.Typography.supporting
        message.adjustsFontForContentSizeCategory = true
        contents.addArrangedSubview(message)
        if !ImVaultReadOnlyProbe.shared.hasAuthorizedBookmark {
            let connect = UIButton(type: .system)
            connect.setTitle("连接 Obsidian Vault", for: .normal)
            connect.accessibilityIdentifier = "impress.notes.connect-vault"
            connect.addTarget(self, action: #selector(connectVaultFromEmptyState),
                              for: .touchUpInside)
            contents.addArrangedSubview(connect)
        }
        container.addSubview(contents)
        NSLayoutConstraint.activate([
            contents.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            contents.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            contents.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            contents.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])
        tableView.backgroundView = container

    }

    @objc private func connectVaultFromEmptyState() {
        chooseReadOnlyVault()
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
        controller.searchBar.tintColor = ImpressV3ReviewEnvironment.pilotEnabled
            ? ImpressV3Appearance.accent : titleColor
        controller.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    /// 筛选搜索Action
    private func searchDBByText(_ text:String? = nil)
    {
        if externalMode {
            externalSearchText = text ?? ""
            externalVisibleLimit = ImVaultListPresentation.pageSize
            rebuildExternalRows()
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
        tableView.backgroundColor = ImpressV3ReviewEnvironment.pilotEnabled
            ? ImpressV3Appearance.page : bgColor
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
        externalMode ? visibleExternalNotes.count + (hasMoreExternalNotes ? 1 : 0) : 1
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        externalMode
            ? ((showingCachedIndex || showingPartialIndex)
               ? "Vault 索引预览 · 正在验证"
               : "Obsidian · " + (selectedVaultFolder ?? "全部文档")
                   + " · " + String(matchedExternalCount) + " 篇（只读）")
            : nil
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if externalMode {
            if hasMoreExternalNotes && indexPath.row == visibleExternalNotes.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: "vault-more")
                    ?? UITableViewCell(style: .default, reuseIdentifier: "vault-more")
                var content = UIListContentConfiguration.cell()
                content.text = "加载更多 · 已显示 " + String(visibleExternalNotes.count)
                    + " / " + String(matchedExternalCount)
                content.textProperties.color = ImpressV3Appearance.accent
                cell.contentConfiguration = content
                cell.accessibilityIdentifier = "impress.notes.load-more"
                return cell
            }
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
            content.imageProperties.tintColor = ImpressV3Appearance.accent
            content.textProperties.numberOfLines = 2
            content.secondaryTextProperties.numberOfLines = 2
            cell.contentConfiguration = content
            ImpressV3Appearance.styleGroupedCell(cell)
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        if let note = viewModel.getCurrentNote(indexPath: indexPath) {
            var content = UIListContentConfiguration.subtitleCell()
            content.text = note.mainTitle ?? "无标题"
            let excerpt = (note.markdownText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let directory = (note.directoryPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = excerpt.isEmpty ? "无内容" : String(excerpt.prefix(160))
            content.secondaryText = directory.isEmpty ? preview : directory + " · " + preview
            content.image = UIImage(systemName: excerpt.isEmpty ? "doc.text" : "doc.text.fill")
            content.imageProperties.tintColor = ImpressV3Appearance.accent
            content.textProperties.numberOfLines = 2
            content.secondaryTextProperties.numberOfLines = 3
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            if ImpressV3ReviewEnvironment.pilotEnabled {
                ImpressV3Appearance.styleGroupedCell(cell)
            }
        }
        return cell
    }
    
        func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: false)
        if externalMode {
            if hasMoreExternalNotes && indexPath.row == visibleExternalNotes.count {
                externalVisibleLimit += ImVaultListPresentation.pageSize
                rebuildExternalRows()
                tableView.reloadData()
                return
            }
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
