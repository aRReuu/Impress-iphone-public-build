//
//  ImPreChatListViewController.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 7/28/25.
//

import UIKit
import Combine

/// 预设聊天列表控制器
class ImPreChatListViewController: ImBaseViewController {
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let reuseID = ImPreChatListCell.reuseIdentifier

    // MARK: - Properties
    private var viewModel: ImPreChatListViewModelProtocol!

    // MARK: - Initialization
    init() {
        self.viewModel = ImPreChatListViewModel()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupBindings()
        loadData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "标记问题"
        navigationItem.largeTitleDisplayMode = .always
        searchControllerSetting()
        view.backgroundColor = bgColor

        // 模态跳转时添加关闭窗口
        if isPresented() {
            initNaviBar()
        }

        // Add new pre-chat button with enhanced styling
//        let addButton = UIBarButtonItem(
//            image: UIImage(systemName: "plus.circle.fill"),
//            style: .plain,
//            target: self,
//            action: #selector(addNewPreChat)
//        )
//        addButton.accessibilityLabel = "添加新标记问题"
//        navigationItem.rightBarButtonItem = addButton
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = bgColor
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        tableView.register(ImPreChatListCell.self, forCellReuseIdentifier: ImPreChatListCell.reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
    }

    private func setupBindings() {
        viewModel.itemsPublisher
            .combineLatest(viewModel.filterPreChatsPublisher, viewModel.isFilterPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                self?.handleAction(action)
            }
            .store(in: &cancellables)
    }

    private func loadData() {
        viewModel.fetchPreChats()
    }

    // MARK: - Actions
    @objc private func addNewPreChat() {
        let submitVC = ImSubmitViewController(submitModel: viewModel.createNewPreChat(question: "", content: ""))
        submitVC.submitActionResult = { [weak self] (preChat: ImPreChatModel) in
            self?.viewModel.insertItem(preChat)
        }
        present(submitVC, animated: true, completion: nil)
    }

    private func editPreChat(at indexPath: IndexPath) {
        guard let preChat = viewModel.getItem(at: indexPath.row) else { return }
        let submitVC = ImSubmitViewController(submitModel: preChat)
        submitVC.isEditMode = true
        submitVC.submitActionResult = { [weak self] (updatedPreChat: ImPreChatModel) in
            self?.viewModel.updateItem(updatedPreChat)
        }
        present(submitVC, animated: true, completion: nil)
    }

    private func deletePreChat(at indexPath: IndexPath) {
        ImAlertController.alert(message: "确定要删除这个标记问题吗？\(deleteReviewMissionWarning)", buttons: alertDescription) { [weak self] (result) in
            if case .ok = result {
                self?.viewModel.deleteItem(at: indexPath.row)
            }
        }
    }

    private func handleAction(_ action: ImGenericAction) {
        switch action {
        case .loading(let isLoading):
            if isLoading {
                loadShare.show()
            } else {
                loadShare.hide()
            }
        case .success(let message):
            ImAlertController.alert(message: message)
        case .error(let error):
            ImAlertController.warningAlert(error.localizedDescription)
        }
    }

    private func searchControllerSetting() {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchBar.placeholder = "问题/内容/来源搜索..."
        controller.searchBar.delegate = self
        controller.searchBar.tintColor = titleColor
        controller.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func searchDBByText(_ text: String? = nil) {
        guard let t = text, !t.isEmpty else {
            viewModel.updateStatusInFilter()
            return
        }
        viewModel.predicatePreChatSeriesDatas(filterText: t)
    }

    /// 检查是否为模态呈现
    private func isPresented() -> Bool {
        return (self.presentingViewController != nil)
    }

    /// 初始化导航栏样式，添加关闭按钮
    private func initNaviBar() {
        self.isModalInPresentation = true
        let leftItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle.fill")?.withConfiguration(
                UIImage.SymbolConfiguration(weight: .semibold)
            ),
            style: .plain,
            target: self,
            action: #selector(exitVC)
        )
        
        leftItem.tintColor = funBtnColor
        leftItem.accessibilityLabel = "关闭标记问题列表"
        navigationItem.leftBarButtonItem = leftItem
    }

    /// 退出视图控制器
    @objc private func exitVC() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension ImPreChatListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.itemCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ImPreChatListCell.reuseIdentifier, for: indexPath) as? ImPreChatListCell,
              let preChat = viewModel.getItem(at: indexPath.row) else {
            return UITableViewCell()
        }
//        cell.backgroundColor = tableViewBGColor
        cell.configure(with: preChat)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Handle pre-chat selection - could navigate to chat or edit mode
        editPreChat(at: indexPath)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deletePreChat(at: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return impressCellDelDes
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let editAction = UIAction(title: "编辑", image: UIImage(systemName: "pencil")) { [weak self] action in
                self?.editPreChat(at: indexPath)
            }
            let deleteAction = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] action in
                self?.deletePreChat(at: indexPath)
            }
            let startChatAction = UIAction(title: "开始对话", image: UIImage(systemName: "message")) { [weak self] action in
                self?.startChat(at: indexPath)
            }
            return UIMenu(title: "", children: [startChatAction, editAction, deleteAction])
        }
    }

    private func startChat(at indexPath: IndexPath) {
        guard let preChat = viewModel.getItem(at: indexPath.row),
              let question = preChat.question, !question.isEmpty else {
            ImAlertController.warningAlert("标记问题内容为空")
            return
        }

        // 边界检查：确保tabBarController存在且为ImTabBarViewController类型
        guard let tabBarController = navigationController?.tabBarController as? ImTabBarViewController else {
            ImAlertController.warningAlert("无法访问标签栏控制器")
            return
        }

        // 切换到对话页面（索引1）
        tabBarController.selectedIndex = 1

        // TODO:
        // 将标记问题注入到输入框中
//        tabBarController.pollingChatVC.startNewChat(with: question)
    }
}

// MARK: - UISearchBarDelegate
extension ImPreChatListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchDBByText(searchText)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchDBByText()
    }
}
