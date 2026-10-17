import UIKit
import Combine

extension ImPreChatListCell {
    func configure(with chat: ImPollingChatModel) {
        questionLabel.text = chat.title ?? "无标题"
        contentLabel.text = chat.subTitle ?? "无副标题"
        if let updateTime = chat.updateTime {
            sourceLabel.text = "更新时间: " + updateTime.dateToString()
            sourceLabel.isHidden = false
        } else {
            sourceLabel.isHidden = true
        }

        // 显示状态指示器 - 根据是否有消息来设置
        let hasMessages = !(chat.messages?.isEmpty ?? true)
        if hasMessages {
            statusIndicator.image = UIImage(systemName: "message.fill")
            statusIndicator.tintColor = .systemGreen
        } else {
            statusIndicator.image = UIImage(systemName: "circle")
            statusIndicator.tintColor = .systemGray
        }
    }
}


class ImPollingChatListViewController: ImBaseViewController {
    private var cancellables = Set<AnyCancellable>()
    
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let reuseID = ImPreChatListCell.reuseIdentifier
    
    private var viewModel: ImPollingChatListViewModelProtocol!
    
    private var selectedChat : ImPollingChatModel?
    
    private var canScrollToSelect: Bool = false
    
    convenience init(chat: ImPollingChatModel? = nil) {
        self.init()
        guard let chat = chat else { return }
        self.selectedChat = chat
        self.canScrollToSelect = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = ImPollingChatListViewModel()
        initUISetting()
        initTableViewSetting()
        setupBindings()
        fetchChats()
    }
    
    func fetchChats()
    {
        viewModel.fetchChats()
    }
}

// MARK: - UI Settings
extension ImPollingChatListViewController {
    private func initUISetting() {
        title = "AI问答记录"
        navigationItem.largeTitleDisplayMode = .always
        searchControllerSetting()
    }
}

// MARK: - SearchBar
extension ImPollingChatListViewController: UISearchBarDelegate {
    private func searchControllerSetting() {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchBar.placeholder = "对话内容搜索..."
        controller.searchBar.delegate = self
        controller.searchBar.tintColor = titleColor
        controller.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    private func searchDBByText(_ text:String? = nil) {
        guard let t = text, !t.isEmpty else {
            viewModel.updateStatusInFliter()
            return
        }
        viewModel.predicateChatSeriesDatas(filterText: t)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchDBByText(searchText)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchDBByText()
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension ImPollingChatListViewController: UITableViewDelegate, UITableViewDataSource {
    private func initTableViewSetting() {
        view.addSubview(tableView)
        tableView.backgroundColor = bgColor
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.showsVerticalScrollIndicator = false
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            tableView.leftAnchor.constraint(equalTo: safeArea.leftAnchor),
            tableView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            tableView.rightAnchor.constraint(equalTo: safeArea.rightAnchor)
        ])
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ImPreChatListCell.self, forCellReuseIdentifier: reuseID)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.chatCount
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseID,
                                                     for: indexPath) as? ImPreChatListCell,
              let chat = viewModel.getChat(at: indexPath) else {
            return UITableViewCell()
        }
        cell.configure(with: chat)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let chat = viewModel.getChat(at: indexPath), let sessionId = chat.identifier else { return }
        NotificationCenter.default.post(name: .didSelectChatSession, object: String(sessionId))
        sliderController?.closeMenu()
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let editContentAction = UIAction(title: "编辑内容", image: UIImage(systemName: "pencil")) { [weak self] action in
                self?.editContent(indexPath)
            }
            let convertToCardAction = UIAction(title: "转换为卡片", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] action in
                self?.convertToCard(indexPath)
            }
            let bindToCardAction = UIAction(title: "绑定会话ID到指定卡片", image: UIImage(systemName: "link")) { [weak self] action in
                self?.bindToCard(indexPath)
            }
            let deleteAction = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] action in
                self?.deleteAction(indexPath)
            }
            return UIMenu(title: "", children: [editContentAction, convertToCardAction, bindToCardAction, deleteAction])
        }
    }

    private func convertToCard(_ indexPath: IndexPath) {
        guard let chat = viewModel.getChat(at: indexPath) else { return }
        guard let title = chat.title, !title.isEmpty else {
            ImAlertController.warningAlert("聊天标题为空，无法转换为卡片。")
            return
        }

        var cardModel = ImCardModel()
        cardModel.question = title
        cardModel.answer = chat.subTitle
        cardModel.cardType = CardType.standard.rawValue
        cardModel.createTime = Date()
        // 关联当前会话ID，用于后续的会话恢复功能
        cardModel.chatSessionId = chat.identifier
        // FSRS initial state
        cardModel.state = CardState.new.rawValue
        cardModel.dueDate = Date()
        cardModel.difficulty = 0.0
        cardModel.stability = 0.0
        cardModel.reviewCount = 0
        cardModel.lapseCount = 0
        cardModel.relearningStep = 0

        let submitVC = ImSubmitViewController(submitModel: cardModel)
        submitVC.submitActionResult = { (updatedCard: ImCardModel) in
            let cardTable = ImDBTableType.card.description
            dbShare.insertToDB(intoTable: cardTable, with: [updatedCard]) { result in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    switch result {
                    case .success():
                        ImAlertController.alert(message: "卡片已成功创建！")
                    case .failure(let error):
                        ImAlertController.warningAlert("创建卡片失败：\(error.localizedDescription)")
                    }
                }
            }
        }
        present(submitVC, animated: true, completion: nil)
    }

    private func bindToCard(_ indexPath: IndexPath) {
        guard let chat = viewModel.getChat(at: indexPath),
              let sessionId = chat.identifier else {
            ImAlertController.warningAlert("无法获取会话信息")
            return
        }
        // 创建选择模式的卡片列表控制器
        let cardListVC = ImCardListViewController.init(isSelectionMode: true, chatSessionId: sessionId)
        navigationController?.pushViewController(cardListVC, animated: true)
    }

    private func editContent(_ indexPath: IndexPath) {
        guard let chat = viewModel.getChat(at: indexPath) else {
            ImAlertController.warningAlert("无法获取对话数据")
            return
        }

        // 检查是否有有效内容编辑
        let hasTitle = !(chat.title?.isEmpty ?? true)
        let hasMessages = !(chat.messages?.isEmpty ?? true)

        if !hasTitle && !hasMessages {
            ImAlertController.warningAlert("该对话没有内容可编辑")
            return
        }

        let submitVC = ImSubmitViewController(submitModel: chat)
        submitVC.isEditMode = true
        submitVC.submitActionResult = { [weak self] (updatedChat: ImPollingChatModel) in
            guard let self = self else { return }

            // 边界检查：确保更新后仍有必要内容
            let updatedTitle = updatedChat.title ?? ""
            if updatedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ImAlertController.warningAlert("标题不能为空")
                return
            }

            // 通过 ViewModel 更新聊天内容，包括数据库操作
            self.viewModel.updateChat(at: indexPath, with: updatedChat)
        }

        present(submitVC, animated: true, completion: nil)
    }

    private func deleteAction(_ indexPath: IndexPath) {
        ImAlertController.alert(message: deleteReviewMissionWarning, buttons: alertDescription) { [weak self] (result) in
            guard let self = self, case .ok = result else { return }
            self.viewModel.deleteChat(at: indexPath)
        }
    }
    
    private func scrollToSelectedChatIfApplicable() {
        guard let selectedChat = selectedChat, let indexPath = viewModel.indexPath(for: selectedChat) else {
            return
        }
        
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}

// MARK: - ViewModel Bindings
extension ImPollingChatListViewController {
    private func setupBindings() {
        viewModel.chatsPublisher
            .combineLatest(viewModel.filterChatsPublisher, viewModel.isFilterPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.tableView.reloadData()
                if self?.canScrollToSelect == true {
                    self?.canScrollToSelect = false
                    self?.scrollToSelectedChatIfApplicable()
                }
            }
            .store(in: &cancellables)
            
        viewModel.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { action in
                switch action {
                // TODO: 后续优化, 与上面信号冲突
//                case .deleteChat(let indexPath):
//                    self?.tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
//                    break
                case .success(let message):
                    ImAlertController.alert(message: message)
                case .errorOccurred(let error):
                    ImAlertController.warningAlert(error.localizedDescription)
                }
            }
            .store(in: &cancellables)
    }
}
