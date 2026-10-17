import UIKit
import Combine

class ImPollingChatViewController: ImBaseViewController {
    private let tableView = UITableView()
    private let llmSelectionButton = UIButton(type: .system)
    private let scrollToBottomButton = UIButton(type: .system)

    private let chatInputView = ChatInputContainerView()

    var viewModel: ImPollingChatViewModelType!
    private var cancellables = Set<AnyCancellable>()

    private var messages: [ImPollingChatMessage] = []
    private var currentModel: ImLLMModel?

    // Search related properties
    private var customSearchView: CustomChatSearchBar!
    private var searchResults: [(messageIndex: Int, range: NSRange)] = []
    private var currentSearchIndex: Int = -1
    private var isSearchVisible: Bool = false

    // Layout constraints (for dynamic search bar support and keyboard handling)
    private var tableViewTopConstraint: NSLayoutConstraint!
    private var chatInputViewBottomConstraint: NSLayoutConstraint!



    // MARK: - Initialization
    /// 设计化的初始化器，支持依赖注入
    init(viewModel: ImPollingChatViewModelType = ImPollingChatViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Deinitialization
    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupCustomSearchView() // 设置自定义搜索栏
        setupKeyboardHandling() // 添加键盘处理
        setupBindings()
        setupInputViewCallbacks()
        setupLifecycleBindings()

        // 配置输入框最大高度（支持更多行数）- 优化为更符合HIG的高度
        chatInputView.setMaxInputHeight(160)

        // ViewModel 生命周期管理
        viewModel.setupLifecycleObservers()
        viewModel.loadDefaultModel()
        viewModel.fetchPresetQuestions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        idleSet(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        idleSet(false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // 设备旋转时，重新计算键盘位置
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self = self else { return }

            // 如果键盘当前是显示状态，重新应用键盘偏移
            if self.chatInputViewBottomConstraint?.constant != -defaultSpacing {
                // 键盘显示中，重新计算偏移
                let safeAreaBottom = self.view.safeAreaInsets.bottom
                let keyboardHeight = self.view.frame.height - safeAreaBottom - self.chatInputView.frame.maxY

                if keyboardHeight > 0 {
                    let inputViewBottomOffset = keyboardHeight - safeAreaBottom
                    let maxOffset = self.view.frame.height - self.view.safeAreaInsets.top - 100
                    let clampedOffset = min(inputViewBottomOffset, maxOffset)

                    self.chatInputViewBottomConstraint?.constant = -clampedOffset

                    // 重新调整TableView的contentInset
                    var contentInset = self.tableView.contentInset
                    contentInset.bottom = clampedOffset + self.chatInputView.frame.height + 16
                    self.tableView.contentInset = contentInset

                    var scrollIndicatorInsets = self.tableView.scrollIndicatorInsets
                    scrollIndicatorInsets.bottom = contentInset.bottom
                    self.tableView.scrollIndicatorInsets = scrollIndicatorInsets
                }
            }
        }
    }

    public func startNewChat(with initialText: String) {
        if !initialText.isEmpty {
            chatInputView.setUserInputText(initialText)
        } else {
            chatInputView.clearInput()
        }
    }

    private func setupViews() {
        view.backgroundColor = bgColor
        setupTableView()
        setupUI()
        setupConstraints()
    }

    private func setupUI() {
        setupNavigationBar()
        setupCustomSearchView()
        scrollToBottomButton.setImage(UIImage(systemName: "chevron.down.circle.fill"), for: .normal)
        scrollToBottomButton.tintColor = funBtnColor
        scrollToBottomButton.backgroundColor = scrollButtonBackgroundColor
        scrollToBottomButton.layer.cornerRadius = defaultSpacing * 2
        scrollToBottomButton.addTarget(self, action: #selector(scrollToBottom), for: .touchUpInside)
        scrollToBottomButton.isHidden = true
        view.addSubview(scrollToBottomButton)

        view.addSubview(chatInputView)
    }

    private func setupConstraints() {
        [tableView, scrollToBottomButton, chatInputView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // Create dynamic table view top constraint
        tableViewTopConstraint = tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)

        let tableViewConstant = defaultSpacing / 2.0
        NSLayoutConstraint.activate([
            // Table view - with dynamic top constraint
            tableViewTopConstraint,
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor,constant: tableViewConstant),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,constant: -tableViewConstant),
            tableView.bottomAnchor.constraint(equalTo: chatInputView.topAnchor, constant: -tableViewConstant),
            
            // Scroll to bottom button
            scrollToBottomButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            scrollToBottomButton.bottomAnchor.constraint(equalTo: chatInputView.topAnchor),
            scrollToBottomButton.widthAnchor.constraint(equalToConstant: defaultSpacing * 4),
            scrollToBottomButton.heightAnchor.constraint(equalToConstant: defaultSpacing * 4),



            // Chat input view
            chatInputView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: defaultSpacing),
            chatInputView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -defaultSpacing)
        ])

        // Create dynamic chat input view bottom constraint for keyboard handling
        chatInputViewBottomConstraint = chatInputView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -defaultSpacing)
        chatInputViewBottomConstraint.isActive = true

        NSLayoutConstraint.activate([
        ])
    }
}

// MARK: - Keyboard Handling
extension ImPollingChatViewController {

    private func setupKeyboardHandling() {
        // 添加键盘通知监听
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(keyboardWillShow(_:)),
                                             name: UIResponder.keyboardWillShowNotification,
                                             object: nil)

        NotificationCenter.default.addObserver(self,
                                             selector: #selector(keyboardWillHide(_:)),
                                             name: UIResponder.keyboardWillHideNotification,
                                             object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }

        // 确保键盘高度有效（过滤掉无效的键盘通知，比如某些输入法的特殊状态）
        let keyboardHeight = keyboardFrame.height
        guard keyboardHeight > 0 else { return }

        let safeAreaBottom = view.safeAreaInsets.bottom

        // 计算输入框需要上移的距离
        // 考虑安全区域，因为输入框已经固定在safeAreaLayoutGuide.bottomAnchor
        let inputViewBottomOffset = keyboardHeight - safeAreaBottom

        // 限制最大上移距离，避免输入框超出屏幕
        let maxOffset = view.frame.height - view.safeAreaInsets.top - 100 // 保留至少100pt可见区域
        let clampedOffset = min(inputViewBottomOffset, maxOffset)

        // 动画选项
        let animationOptions = UIView.AnimationOptions(rawValue: animationCurve << 16)

        UIView.animate(withDuration: animationDuration,
                      delay: 0,
                      options: animationOptions,
                      animations: { [weak self] in
            guard let self = self else { return }

            // 调整输入框位置 - 修改底部约束
            self.chatInputViewBottomConstraint?.constant = -clampedOffset

            // 调整TableView的contentInset，让用户能看到更多内容
            var contentInset = self.tableView.contentInset
            contentInset.bottom = clampedOffset + self.chatInputView.frame.height + 16
            self.tableView.contentInset = contentInset

            var scrollIndicatorInsets = self.tableView.scrollIndicatorInsets
            scrollIndicatorInsets.bottom = contentInset.bottom
            self.tableView.scrollIndicatorInsets = scrollIndicatorInsets

            self.view.layoutIfNeeded()

        }) { [weak self] _ in
            // 键盘显示动画完成后，滚动到最底部（如果需要）
            self?.scrollToBottomIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }

        let animationOptions = UIView.AnimationOptions(rawValue: animationCurve << 16)

        UIView.animate(withDuration: animationDuration,
                      delay: 0,
                      options: animationOptions,
                      animations: { [weak self] in
            guard let self = self else { return }

            // 恢复输入框位置
            self.chatInputViewBottomConstraint?.constant = -defaultSpacing

            // 恢复TableView的contentInset
            var contentInset = self.tableView.contentInset
            contentInset.bottom = 0
            self.tableView.contentInset = contentInset

            var scrollIndicatorInsets = self.tableView.scrollIndicatorInsets
            scrollIndicatorInsets.bottom = 0
            self.tableView.scrollIndicatorInsets = scrollIndicatorInsets

            self.view.layoutIfNeeded()

        }, completion: nil)
    }

    private func scrollToBottomIfNeeded() {
        // 如果用户正在查看底部消息，不滚动
        let offsetY = tableView.contentOffset.y
        let contentHeight = tableView.contentSize.height
        let frameHeight = tableView.frame.size.height

        // 如果距离底部超过一个屏幕的高度，才滚动
        if contentHeight - offsetY - frameHeight > frameHeight {
            scrollToBottom()
        }
    }
}


// MARK: - Lifecycle Bindings
extension ImPollingChatViewController {
    private func setupLifecycleBindings() {
        // 当前模型变化绑定
        viewModel.currentModelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                guard let self = self else { return }
                self.currentModel = model
                let buttonTitle = self.viewModel.getLLMButtonTitle(for: model)
                self.updateMenu(withFirstItemTitle: "当前模型:\(buttonTitle)")

                // 更新占位符
                let placeholder = model?.name.map { "Ask \($0)" } ??
                                 model?.provider.map { "Ask \($0)" } ??
                                 "请输入内容..."
                self.chatInputView.setPlaceholder(placeholder)
            }
            .store(in: &cancellables)

        // 会话选择绑定
        viewModel.sessionSelectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionId in
                self?.viewModel.loadSession(withId: sessionId)
            }
            .store(in: &cancellables)

        // 应用后台事件绑定
        viewModel.backgroundEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.viewModel.saveDraft()
            }
            .store(in: &cancellables)

        // 默认模型加载完成绑定
        viewModel.defaultModelLoadedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                guard let self = self else { return }
                self.currentModel = model
                let buttonTitle = self.viewModel.getLLMButtonTitle(for: model)
                self.updateMenu(withFirstItemTitle: buttonTitle)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Navigation Bar Management
extension ImPollingChatViewController
{

    func setupNavigationBar()
    {
        navigationItem.largeTitleDisplayMode = .never
        let leftItem = UIBarButtonItem(image: UIImage(systemName: "sidebar.leading"),
                                               style: .plain,
                                               target: self,
                                               action: #selector(showChatList))
        let obItem = UIBarButtonItem(image: UIImage(systemName: "note.text"),
                                     style: .plain,
                                     target: self,
                                     action: #selector(showNoteList))
        navigationItem.leftBarButtonItems = [leftItem, obItem]
        //
        let rightMenuItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle.fill"),
                                            style: .plain,
                                            target: self,
                                            action: nil)
        rightMenuItem.tintColor = funBtnColor
        updateMenu(withFirstItemTitle: "选择模型")
        navigationItem.rightBarButtonItem = rightMenuItem
    }

    private func updateMenu(withFirstItemTitle firstItemTitle: String)
    {
        let selectModelAction = UIAction(title: firstItemTitle, image: UIImage(systemName: "brain.head.profile")) { [weak self] _ in
            self?.showLLMConfig()
        }



        let searchAction = UIAction(title: "搜索消息", image: UIImage(systemName: "magnifyingglass")) { [weak self] _ in
            self?.toggleSearchView()
        }

        let systemPromptAction = UIAction(title: "系统提示词编辑", image: UIImage(systemName: "text.bubble")) { [weak self] _ in
            self?.showSystemPromptEditor()
        }

        let newChatAction = UIAction(title: "新对话", image: UIImage(systemName: "plus.message.fill")) { [weak self] _ in
            self?.startNewChatFromButton()
        }

        let menu = UIMenu(title: "", children: [selectModelAction, systemPromptAction, searchAction, newChatAction])
        navigationItem.rightBarButtonItem?.menu = menu
    }

    private func setupCustomSearchView() {
        // Initialize custom search view
        customSearchView = CustomChatSearchBar()

        // Set up callbacks for custom search bar
        customSearchView.onSearchTextChanged = { [weak self] searchText in
            self?.performSearch(searchText)
        }

        customSearchView.onSearchButtonPressed = { [weak self] searchText in
            self?.performCompleteSearch(searchText)
        }

        customSearchView.onClearButtonPressed = { [weak self] in
            self?.clearSearchResults()
        }

        customSearchView.onNavigateUp = { [weak self] in
            self?.navigateToPreviousResult()
        }

        customSearchView.onNavigateDown = { [weak self] in
            self?.navigateToNextResult()
        }

        // Update navigation buttons state when search results change
        updateSearchNavigationButtons()
    }

    @objc private func startNewChatFromButton() {
        // 放弃输入框的键盘第一响应，提供更好的用户体验
        view.endEditing(true)

        let currentSession = viewModel.currentChatSession.value
        let hasContent = !(currentSession.messages?.isEmpty ?? true)
        let isDraft = hasContent && (currentSession.title == nil || currentSession.title!.isEmpty)
        let isHistoricalData = currentSession.identifier != nil && currentSession.title != nil && !currentSession.title!.isEmpty

        if isHistoricalData {
            viewModel.startNewSession()
        } else if isDraft {
            promptToSaveDraftOrStartNew()
        } else if hasContent {
            feynmanConcluded { [weak self] in
                self?.viewModel.startNewSession()
            }
        } else {
            viewModel.startNewSession()
        }
        // fix 底部按钮隐藏
        scrollToBottomButton.isHidden = true

    }

    private func promptToSaveDraftOrStartNew() {
        ImAlertController.alert(message: "您想保存当前草稿，还是直接开始新的对话？", buttons: ["直接开始","费曼保存"]) { [weak self] result in
            switch result {
            case .ok: // 费曼保存
                self?.feynmanConcluded {
                    self?.viewModel.startNewSession()
                }
            case .cancel: // 直接开始
                self?.viewModel.startNewSession()
            }
        }
    }

    @objc private func showChatList() {
        sliderController?.toggleMenu()
    }

    @objc private func showNoteList() {
        let noteListVC = ImpressNoteListTableViewController()
        noteListVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(noteListVC, animated: true)
    }

    @objc private func toggleSearchView() {
        if customSearchView.superview == nil {
            showSearchView()
        } else {
            hideSearchView()
        }
    }

    private func showSearchView() {
        guard !messages.isEmpty else {
            ImAlertController.warningAlert("暂无对话内容可搜索")
            return
        }

        customSearchView.alpha = 0
        view.addSubview(customSearchView)

        customSearchView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customSearchView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customSearchView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customSearchView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customSearchView.heightAnchor.constraint(equalToConstant: 72) // 56pt search bar + 8pt padding each side
        ])

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.customSearchView.alpha = 1
        }) { [weak self] _ in
            self?.customSearchView.showKeyboard()
        }

        isSearchVisible = true
        updateTableViewLayout()
    }

    private func hideSearchView() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseIn, animations: {
            self.customSearchView.alpha = 0
        }) { [weak self] _ in
            guard let self = self else { return }
            self.customSearchView.removeFromSuperview()
            self.customSearchView.clearSearch()
        }

        isSearchVisible = false
        updateTableViewLayout()
    }

    private func updateTableViewLayout() {
        // Adjust table view top constraint based on search visibility
        let newTopConstant: CGFloat = isSearchVisible ? 80 : 8  // 72pt search bar height + 8pt spacing

        // Animate the constraint change
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.tableViewTopConstraint.constant = newTopConstant
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - LLM Selection Button
extension ImPollingChatViewController {
    @objc private func showLLMConfig() {
        let configVC = ImLLMConfigViewController()
        let navVC = ImNavigationViewController(rootViewController: configVC)
        present(navVC, animated: true, completion: nil)
    }



    @objc private func showSystemPromptEditor() {
        let settingsViewModel = ImSettingsViewModel()
        let systemPromptVC = ImSystemPromptViewController(viewModel: settingsViewModel)
        navigationController?.pushViewController(systemPromptVC, animated: true)
    }
}

// MARK: - Session Management
extension ImPollingChatViewController {

    private func feynmanConcluded(completion: (() -> Void)? = nil) {
        var submitModel = viewModel.currentChatSession.value
        submitModel.submitQuestion = submitModel.title ?? "" // 使用现有标题或空字符串

        let submitVC = ImSubmitViewController(submitModel: submitModel)
        submitVC.isDraftMode = true
        submitVC.submitActionResult = { [weak self] updatedChat in
            guard let self = self else { return }
            var updatedSession = self.viewModel.currentChatSession.value
            updatedSession.title = updatedChat.submitQuestion
            updatedSession.subTitle = updatedChat.submitAnswer
            // 保持摘录内容不断开
            updatedSession.extractedTexts = updatedChat.submitExtractedTexts
            self.viewModel.feynmanConcluded(with: updatedSession)
            completion?()
        }
        present(submitVC, animated: true)
    }
}

// MARK: - Underline Operations
extension ImPollingChatViewController {
    /// 处理下划线操作
    private func handleUnderlineOperation(_ operation: ChatSelectableTextView.UnderlineOperation, forMessageId messageId: UUID) {
        switch operation {
        case .add(let range, let text):
            // 边界检查：确保长度不为空，位置有效
            guard range.length > 0,
                  let message = messages.first(where: { $0.id == messageId }),
                  range.location >= 0,
                  range.location + range.length <= message.content.utf16.count else {
                return
            }

            // 验证文本内容非空
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                return
            }

            // 添加下划线到消息
            viewModel.addUnderline(toMessageWithId: messageId, range: range, text: trimmedText)

            // 添加到摘录数组中，避免重复
            var currentExtractedTexts = viewModel.currentChatSession.value.extractedTexts ?? []
            if !currentExtractedTexts.contains(trimmedText) {
                currentExtractedTexts.append(trimmedText)
                var updatedSession = viewModel.currentChatSession.value
                updatedSession.extractedTexts = currentExtractedTexts
                viewModel.feynmanConcluded(with: updatedSession)
            }

        case .remove(let underlineId):
            viewModel.removeUnderline(fromMessageWithId: messageId, underlineId: underlineId)

            // 从摘录数组中同步删除对应的内容
            if let underlineToRemove = messages.first(where: { $0.id == messageId })?.underlines?.first(where: { $0.id == underlineId }) {
                var currentExtractedTexts = viewModel.currentChatSession.value.extractedTexts ?? []
                currentExtractedTexts.removeAll { $0 == underlineToRemove.text }
                var updatedSession = viewModel.currentChatSession.value
                updatedSession.extractedTexts = currentExtractedTexts
                viewModel.feynmanConcluded(with: updatedSession)
            }
        }
    }
}

// MARK: - Help Methods
extension ImPollingChatViewController {


    private func sendMessage() {
        let text = chatInputView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            ImAlertController.warningAlert("请输入消息内容")
            return
        }

        guard currentModel?.apiKey != nil && currentModel?.modelIdentifier != nil else {
            ImAlertController.warningAlert("请先选择或配置一个AI模型")
            return
        }

        viewModel.sendMessage(text, with: currentModel)
        chatInputView.clearInput()
    }
}

// MARK: - Setup Input View Callbacks
extension ImPollingChatViewController {
    private func setupInputViewCallbacks() {
        chatInputView.onSendMessage = { [weak self] in
            self?.sendMessage()
        }

        chatInputView.onMicPressed = {}

        chatInputView.onTextChanged = {text in}


    }
}

// MARK: - Table View Management
extension ImPollingChatViewController: UITableViewDataSource, UITableViewDelegate {

    func getRetryButton() -> UIButton? {
        guard let footerView = tableView.tableFooterView else { return nil }
        return footerView.viewWithTag(999) as? UIButton
    }

    func setupTableView() {
        tableView.dataSource = self
        tableView.backgroundColor = bgColor
        tableView.delegate = self
        tableView.register(ImPollingChatCell.self, forCellReuseIdentifier: ImPollingChatCell.reuseIdentifier)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        tableView.tableFooterView = createFooterView()
        view.addSubview(tableView)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ImPollingChatCell.reuseIdentifier, for: indexPath) as? ImPollingChatCell else {
            return UITableViewCell()
        }
        cell.configure(with: messages[indexPath.row])

        // 设置下划线操作回调
        cell.onUnderlineOperation = { [weak self] operation, messageId in
            guard let self = self else { return }
            self.handleUnderlineOperation(operation, forMessageId: messageId)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        ImAlertController.alert(message: "是否删除这条消息？", buttons: alertDescription) {[weak self] (result) in
            if case .ok = result {
                self?.viewModel.deleteMessage(at: indexPath)
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height
        let shouldShowButton = contentHeight > frameHeight && (contentHeight - offsetY - frameHeight) > 200

        if shouldShowButton != !scrollToBottomButton.isHidden {
            UIView.transition(with: scrollToBottomButton, duration: 0.25, options: .transitionCrossDissolve, animations: {
                self.scrollToBottomButton.isHidden = !shouldShowButton
            })
        }
    }

    @objc func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        scrollToBottomButton.isHidden = true
    }

    private func createFooterView() -> UIView {
        let retryButton = UIButton(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: defaultSpacing * 2))
        retryButton.tag = 999
        retryButton.backgroundColor = .clear
        retryButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        retryButton.tintColor = funBtnColor
        retryButton.addTarget(self, action: #selector(retryLastRequest), for: .touchUpInside)
        return retryButton
    }

    @objc private func retryLastRequest() {
        viewModel.retryLastRequest(with: currentModel)
    }

    private func createEmptyStateBackgroundView() -> UIView {
        let containerView = UIView(frame: tableView.bounds)

        // 主标题 - 知识原子化
        let titleLabel = UILabel()
        titleLabel.text = "知识原子化"
        titleLabel.textColor = funBtnColor
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 副标题 - 提示信息
        let subtitleLabel = UILabel()
        subtitleLabel.text = "开始与AI对话，原子化你的知识"
        subtitleLabel.textColor = contentColor
        subtitleLabel.textAlignment = .center
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 图标
        let iconView = UIImageView(image: UIImage(systemName: "brain.head.profile"))
        iconView.tintColor = funBtnColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(iconView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)

        
        NSLayoutConstraint.activate([
            // 图标居中，位于上方
            iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -60),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),

            // 主标题在图标下方
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: defaultSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),

            // 副标题在主标题下方
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: defaultSpacing),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40)
        ])

        return containerView
    }
}

// MARK: - ViewModel Bindings
extension ImPollingChatViewController {
    private func setupBindings() {
        // 消息更新绑定
        viewModel.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                guard let self = self else { return }
                self.messages = messages
                self.tableView.reloadData()

                if messages.last?.sender == .bot && messages.last?.status == .sent {
                    // 机器人回复完成，不自动滚动
                } else {
                    self.scrollToBottom()
                }

                if messages.isEmpty {
                    self.tableView.backgroundView = self.createEmptyStateBackgroundView()
                } else {
                    self.tableView.backgroundView = nil
                }


                // 控制重试按钮显示
                let shouldShowRetry = messages.last?.sender == .bot && messages.last?.status == .failed
                self.getRetryButton()?.isHidden = !shouldShowRetry
            }
            .store(in: &cancellables)



        // 新会话开始绑定
        viewModel.newSessionDidStart
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.chatInputView.clearInput()
                self.chatInputView.setPlaceholder("请输入内容...")
                self.getRetryButton()?.isHidden = true
                self.tableView.reloadData()
                self.scrollToBottom()
                // 重新获取标记问题，用于新会话
                self.viewModel.fetchPresetQuestions()
            }
            .store(in: &cancellables)

        // 错误处理绑定
        viewModel.error
            .receive(on: DispatchQueue.main)
            .sink { error in
                ImAlertController.warningAlert(error.localizedDescription)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Search Functionality
extension ImPollingChatViewController {

    private func performSearch(_ searchText: String) {
        guard !searchText.isEmpty else {
            clearSearchResults()
            return
        }

        searchResults.removeAll()
        currentSearchIndex = -1

        for (index, message) in messages.enumerated() {
            if let range = message.content.range(of: searchText, options: .caseInsensitive) {
                let nsRange = NSRange(range, in: message.content)
                searchResults.append((messageIndex: index, range: nsRange))
            }
        }

        updateSearchNavigationButtons()
    }

    private func performCompleteSearch(_ searchText: String) {
        performSearch(searchText)

        if searchResults.isEmpty {
            ImAlertController.warningAlert("未找到匹配内容")
        } else {
            navigateToSearchResult(at: 0)
        }
    }

    private func clearSearchResults() {
        searchResults.removeAll()
        currentSearchIndex = -1

        // 清除所有Cell的高亮
        tableView.visibleCells.forEach { cell in
            if let chatCell = cell as? ImPollingChatCell {
                chatCell.clearSearchHighlight()
            }
        }

        updateSearchNavigationButtons()
    }

    private func updateSearchNavigationButtons() {
        guard isSearchVisible else { return }

        customSearchView.setResultCount(searchResults.count, current: currentSearchIndex)
    }
}

// MARK: - Search Navigation
extension ImPollingChatViewController {

    @objc private func navigateToPreviousResult() {
        guard !searchResults.isEmpty else { return }
        let newIndex = currentSearchIndex > 0 ? currentSearchIndex - 1 : searchResults.count - 1
        navigateToSearchResult(at: newIndex)
    }

    @objc private func navigateToNextResult() {
        guard !searchResults.isEmpty else { return }
        let newIndex = currentSearchIndex < searchResults.count - 1 ? currentSearchIndex + 1 : 0
        navigateToSearchResult(at: newIndex)
    }

    private func navigateToSearchResult(at index: Int) {
        guard index >= 0 && index < searchResults.count else { return }

        currentSearchIndex = index
        let result = searchResults[index]
        let indexPath = IndexPath(row: result.messageIndex, section: 0)

        // 滚动到指定位置
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)

        // 延迟获取cell并高亮
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }

            // 清除之前的所有高亮
            self.tableView.visibleCells.forEach { cell in
                if let chatCell = cell as? ImPollingChatCell {
                    chatCell.clearSearchHighlight()
                }
            }

            // 高亮当前匹配，传递消息类型信息
            if let cell = self.tableView.cellForRow(at: indexPath) as? ImPollingChatCell {
                let message = self.messages[result.messageIndex]
                let isMarkdownMessage = message.sender == .bot
                let originalContent = isMarkdownMessage ? message.content : nil
                cell.highlightSearchResult(with: self.customSearchView.getSearchText(),
                                         range: result.range,
                                         isMarkdownMessage: isMarkdownMessage,
                                         originalContent: originalContent)
            }

            // 更新导航按钮状态
            self.updateSearchNavigationButtons()
        }
    }
}
