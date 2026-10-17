import Foundation
import Combine
import WCDBSwift

class ImPollingChatViewModel: ImPollingChatViewModelType {
    // MARK: - Publishers - 直接暴露，避免复杂的input/output包装
    let currentChatSession: CurrentValueSubject<ImPollingChatModel, Never>
    let messages = CurrentValueSubject<[ImPollingChatMessage], Never>([])
    let scrollToIndexPath = PassthroughSubject<IndexPath, Never>()
    let showMenuForCell = PassthroughSubject<IndexPath, Never>()
    let presetQuestions = CurrentValueSubject<[String], Never>([])
    let newSessionDidStart = PassthroughSubject<Void, Never>()
    let showAssistMenuPublisher = PassthroughSubject<Void, Never>()
    let isLoading = PassthroughSubject<Bool, Never>()
    let error = PassthroughSubject<Swift.Error, Never>()
    let tokenUsage = CurrentValueSubject<TokenUsageInfo?, Never>(nil)

    // MARK: - Lifecycle Publishers
    private let _currentModelSubject = CurrentValueSubject<ImLLMModel?, Never>(nil)
    private let _backgroundEventSubject = PassthroughSubject<Void, Never>()
    private let _sessionSelectionSubject = PassthroughSubject<String, Never>()
    private let _defaultModelLoadedSubject = PassthroughSubject<ImLLMModel?, Never>()

    var currentModelPublisher: AnyPublisher<ImLLMModel?, Never> {
        _currentModelSubject.eraseToAnyPublisher()
    }

    var backgroundEventPublisher: AnyPublisher<Void, Never> {
        _backgroundEventSubject.eraseToAnyPublisher()
    }

    var sessionSelectionPublisher: AnyPublisher<String, Never> {
        _sessionSelectionSubject.eraseToAnyPublisher()
    }

    var defaultModelLoadedPublisher: AnyPublisher<ImLLMModel?, Never> {
        _defaultModelLoadedSubject.eraseToAnyPublisher()
    }

    private var searchResults: [IndexPath] = []
    private var currentSessionTokens: Int = 0
    private let maxTokensForSession: Int = 8192 // Set a reasonable limit for the session
    private var currentSearchIndex: Int = -1
    private var selectedModel: ImLLMModel?
    private let chatTable = ImDBTableType.pollingChat.description
    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Initialization
    // The single designated initializer for the ViewModel.
    init(chatSession: ImPollingChatModel? = nil) {
        if let session = chatSession {
            currentChatSession = CurrentValueSubject(session)
        } else {
            currentChatSession = CurrentValueSubject(ImPollingChatModel()) // Start with a temporary empty session
        }
        setupBindings()

        // If no session was provided, it's our responsibility to load the last draft or start a new one.
        if chatSession == nil {
            loadLastDraftOrStartNew()
        }
    }

    private func loadLastDraftOrStartNew() {
        // 查询所有空标题（草稿）会话
        let query = ImPollingChatModel.Properties.title.isNull()
        dbShare.queryFromDB(table: chatTable,
                            cls: ImPollingChatModel.self,
                            where: query, orderBy: [ImPollingChatModel.Properties.updateTime.asOrder(by: .descending)]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let draftSessions):
                    // 加载最近的草稿，包括有消息的草稿，用于恢复用户之前的对话状态
                    if let latestDraft = draftSessions.first {
                        self?.currentChatSession.send(latestDraft)
                    } else {
                        self?.createNewSession()
                    }
                case .failure:
                    self?.createNewSession() // Fallback to new session on error
                }
            }
        }
    }
    
    // MARK: - Business Methods
    func feynmanConcluded(with updatedSession: ImPollingChatModel) {
        currentChatSession.value = updatedSession
        updateChatSession(with: updatedSession.messages ?? [])
    }

    func startNewSession() {
        // Reset token count for the new session
        currentSessionTokens = 0
        tokenUsage.send(nil)

        // 检查是否可以复用当前空草稿，避免累积空的数据库记录
        let currentSession = currentChatSession.value
        let hasContent = !(currentSession.messages?.isEmpty ?? true)
        let isEmptyDraft = !hasContent && currentSession.identifier != nil

        if isEmptyDraft {
            // 复用当前空草稿：重置消息和更新时间即可，无需创建新的数据库记录
            resetCurrentSessionToEmpty()
            return
        }

        // 有内容的会话：保存当前会话并创建新的空会话
        saveCurrentSession { [weak self] in
            self?.createNewSession()
        }
    }

    private func resetCurrentSessionToEmpty() {
        var updatedSession = currentChatSession.value
        updatedSession.messages = []
        updatedSession.updateTime = Date()

        // 更新内存状态
        currentChatSession.send(updatedSession)

        // 发送新会话开始信号，确保UI正确重置
        newSessionDidStart.send()
    }

    private func saveCurrentSession(completion: (() -> Void)? = nil) {
        var sessionToSave = currentChatSession.value
        
        // If the session has an ID, update it.
        if let sessionId = sessionToSave.identifier {
            dbShare.updateToDB(table: chatTable, on: ImPollingChatModel.Properties.all, with: sessionToSave, where: ImPollingChatModel.Properties.identifier == sessionId) { [weak self] result in
                if case .failure(let error) = result {
                    self?.error.send(error)
                }
                completion?()
            }
        } else {
            // If the session has no ID, it's a new draft that needs to be inserted.
            let uniqueTimestamp = Date()
            sessionToSave.updateTime = uniqueTimestamp
            
            dbShare.insertToDB(intoTable: chatTable, with: [sessionToSave]) { [weak self] result in
                guard let self = self else {
                    completion?()
                    return
                }
                
                switch result {
                case .success:
                    // After inserting, we fetch it back to get the ID and update our in-memory session.
                    // This ensures subsequent saves will use the update path.
                    let condition = ImPollingChatModel.Properties.updateTime == uniqueTimestamp
                    dbShare.queryOneObjectFromDB(table: self.chatTable, cls: ImPollingChatModel.self, where: condition) { [weak self] fetchResult in
                        if case .success(let savedSession) = fetchResult {
                            self?.currentChatSession.send(savedSession)
                        }
                        completion?()
                    }
                case .failure(let error):
                    self.error.send(error)
                    completion?()
                }
            }
        }
    }

    private func createNewSession() {
        var newSession = ImPollingChatModel()
        let uniqueTimestamp = Date()
        newSession.updateTime = uniqueTimestamp
        newSession.messages = []

        // Step 1: Insert the new session.
        dbShare.insertToDB(intoTable: chatTable, with: [newSession]) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                // Step 2: Immediately fetch the session we just inserted using the unique timestamp.
                let condition = ImPollingChatModel.Properties.updateTime == uniqueTimestamp
                dbShare.queryOneObjectFromDB(table: self.chatTable,
                                             cls: ImPollingChatModel.self,
                                             where: condition) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let sessionWithId):
                            // Now we have the session with the correct identifier.
                            self.currentChatSession.send(sessionWithId)
                            self.newSessionDidStart.send()
                        case .failure(let error):
                            self.error.send(error)
                        }
                    }
                }
            case .failure(let error):
                self.error.send(error)
            }
        }
    }

    func loadSession(withId sessionId: String) {
        // Reset token count for the new session
        currentSessionTokens = 0
        tokenUsage.send(nil)

        // First, save the current session to ensure no data is lost.
        saveCurrentSession { [weak self] in
            // After saving, proceed to load the new session.
            self?.fetchSession(withId: sessionId)
        }
    }

    private func fetchSession(withId sessionId: String, isNewSession: Bool = false) {
        dbShare.queryOneObjectFromDB(table: chatTable, cls: ImPollingChatModel.self, where: ImPollingChatModel.Properties.identifier == Int(sessionId)!) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let session):
                    self?.currentChatSession.send(session)
                    if isNewSession {
                        self?.newSessionDidStart.send()
                    }
                case .failure(let error):
                    self?.error.send(error)
                }
            }
        }
    }

    func sendMessage(_ content: String, with model: ImLLMModel?) {
        // 1. Ensure a model is selected
        guard let llm = model, llm.apiKey != nil, llm.modelIdentifier != nil else {
            error.send(NSError(domain: "ImPollingChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "发送失败：请先在设置中选择并配置一个有效的语言模型。"]))
            return
        }

        selectedModel = llm // Update selected model for retry

        // 2. Create user message and a temporary bot loading message
        let userMessage = ImPollingChatMessage(id: UUID(), content: content, sender: .user, timestamp: Date(), status: .sent)
        let botMessageId = UUID()
        let botMessage = ImPollingChatMessage(id: botMessageId, content: "", sender: .bot, timestamp: Date(), status: .sending)

        // 3. Update UI and database through a single source of truth
        var updatedMessages = currentChatSession.value.messages ?? []
        updatedMessages.append(userMessage)
        updatedMessages.append(botMessage)
        updateChatSession(with: updatedMessages) // This now drives the UI update

        // 4. Perform the network request
        performChatRequest(with: llm, botMessageId: botMessageId)
    }

    private func performChatRequest(with llm: ImLLMModel, botMessageId: UUID) {
        let history = (currentChatSession.value.messages ?? [])
            .filter { $0.id != botMessageId && ($0.status == .sent || $0.status == nil) }
            .map { message -> [String: String] in
                let role = message.sender == .user ? "user" : "assistant"
                return ["role": role, "content": message.content]
            }

        let systemPrompt = ImNetWorkRequest.shared.getCurrentSystemPrompt()
        ImNetWorkRequest.shared.requestPollingChat(messages: history, llm: llm, systemPrompt: systemPrompt) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                var finalMessages = self.currentChatSession.value.messages ?? []
                if let index = finalMessages.firstIndex(where: { $0.id == botMessageId }) {
                    switch result {
                    case .success(let response):
                        finalMessages[index].content = response.content
                        finalMessages[index].status = .sent

                        // Handle token usage
                        if let usage = response.usage {
                            self.currentSessionTokens += usage.totalTokens
                            let tokenInfo = TokenUsageInfo(currentTokens: self.currentSessionTokens, maxTokens: self.maxTokensForSession)
                            self.tokenUsage.send(tokenInfo)
                        }

                        // Update the main data source to display the complete content
                        self.updateChatSession(with: finalMessages)

                    case .failure(let error):
                        finalMessages[index].content = "请求失败，请重试,错误信息: \(error.localizedDescription)" // 显示错误提示信息
                        finalMessages[index].status = .failed
                        // 不再发送错误到UI层显示弹窗，在消息中显示错误信息
                        // Update UI and database to show failed status
                        self.updateChatSession(with: finalMessages)
                    }
                }
            }
        }
    }

    func deleteMessage(at indexPath: IndexPath) {
        var currentMessages = messages.value
        guard currentMessages.indices.contains(indexPath.row) else { return }
        currentMessages.remove(at: indexPath.row)
        messages.send(currentMessages)
        updateChatSession(with: currentMessages)
    }

    // MARK: - Underline Management

    /// 添加下划线到指定消息
    func addUnderline(toMessageWithId messageId: UUID, range: NSRange, text: String) {
        guard range.length > 0, !text.isEmpty else { return }

        var currentMessages = messages.value
        guard let messageIndex = currentMessages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        // 线程安全：确保在主线程操作UI相关数据
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建新的下划线记录
            let newUnderline = UnderlineRange(id: UUID(),
                                            startIndex: range.location,
                                            length: range.length,
                                            timestamp: Date(),
                                            text: text)

            var updatedMessage = currentMessages[messageIndex]
            var currentUnderlines = updatedMessage.underlines ?? []

            // 检查是否有重叠的下划线，如果有则跳过
            let hasOverlap = currentUnderlines.contains { existing in
                let existingRange = NSRange(location: existing.startIndex, length: existing.length)
                return NSIntersectionRange(existingRange, range).length > 0
            }

            if !hasOverlap {
                currentUnderlines.append(newUnderline)
                updatedMessage.underlines = currentUnderlines
                currentMessages[messageIndex] = updatedMessage

                // 更新UI
                self.messages.send(currentMessages)
                // 同步到数据库
                self.updateChatSession(with: currentMessages)
            }
        }
    }

    /// 移除消息中的下划线
    func removeUnderline(fromMessageWithId messageId: UUID, underlineId: UUID) {
        var currentMessages = messages.value
        guard let messageIndex = currentMessages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        // 线程安全：确保在主线程操作UI相关数据
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var updatedMessage = currentMessages[messageIndex]
            var currentUnderlines = updatedMessage.underlines ?? []

            // 移除指定的下划线
            currentUnderlines.removeAll { $0.id == underlineId }
            updatedMessage.underlines = currentUnderlines
            currentMessages[messageIndex] = updatedMessage

            // 更新UI
            self.messages.send(currentMessages)
            // 同步到数据库
            self.updateChatSession(with: currentMessages)
        }
    }

    /// 批量更新消息的下划线信息（用于数据恢复）
    func updateUnderlines(forMessageWithId messageId: UUID, underlines: [UnderlineRange]) {
        var currentMessages = messages.value
        guard let messageIndex = currentMessages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var updatedMessage = currentMessages[messageIndex]
            updatedMessage.underlines = underlines
            currentMessages[messageIndex] = updatedMessage

            // 更新UI（不触发数据库更新，避免重复保存）
            self.messages.send(currentMessages)
        }
    }

    func search(with query: String) {
        searchResults.removeAll()
        currentSearchIndex = -1

        guard !query.isEmpty else {
            messages.send(currentChatSession.value.messages ?? [])
            return
        }

        let lowercasedQuery = query.lowercased()
        let filteredMessages = (currentChatSession.value.messages ?? []).filter { $0.content.lowercased().contains(lowercasedQuery) }
        messages.send(filteredMessages)
    }
    
    func showNextSearchResult() {
        // The search logic is now based on filtering, so these methods might need rethinking
    }
    
    func showPreviousSearchResult() {
        // The search logic is now based on filtering, so these methods might need rethinking
    }
    
    func longPressCell(at indexPath: IndexPath) {
        showMenuForCell.send(indexPath)
    }

    func triggerAssistMenu() {
        showAssistMenuPublisher.send()
    }

    func fetchPresetQuestions() {
        dbShare.queryRandomObjects(ofCount: defaultChatedNum,
                                   fromTable: ImDBTableType.preChat.description,
                                   cls: ImPreChatModel.self,
                                   where: ImPreChatModel.Properties.isChated == false) {[weak self] (result) in
            switch result {
            case .success(let chats):
                let questions = chats.compactMap { $0.question }
                self?.presetQuestions.send(questions)
            case .failure(let error):
                self?.error.send(error)
            }
        }
    }

    private func setupBindings() {
        // Establish a continuous binding from the single source of truth (currentChatSession) to the UI driver (messages).
        currentChatSession
            .map { $0.messages ?? [] }
            .sink { [weak self] messages in
                self?.messages.send(messages)
            }
            .store(in: &cancellables)

        // Listen for model changes to keep selectedModel in sync
        NotificationCenter.default.addObserver(self, selector: #selector(handleModelChanged(_:)), name: NSNotification.Name(rawValue: "LLMModelDidChange"), object: nil)
    }

    @objc private func handleModelChanged(_ notification: Notification) {
        if let model = notification.object as? ImLLMModel {
            selectedModel = model
        } else {
            selectedModel = nil
        }
    }

    private func updateChatSession(with messages: [ImPollingChatMessage]) {
        var updatedSession = currentChatSession.value
        updatedSession.messages = messages
        updatedSession.updateTime = Date()

        // Update the in-memory state, which drives the UI.
        currentChatSession.send(updatedSession)

        // Persist the changes to the database.
        saveCurrentSession()
    }

    func saveDraft()
    {
        zcLog("保存草稿")
        saveCurrentSession()
    }

    func retryLastRequest(with model: ImLLMModel?)
    {
        // Determine which model to use: prefer passed-in model, fallback to selectedModel
        let modelToUse = model ?? selectedModel

        // Validate model
        guard let finalModel = modelToUse,
              finalModel.apiKey != nil,
              finalModel.modelIdentifier != nil else {
            let errorMessage = model == nil ? "请先选择或配置一个有效的AI模型" : "所选模型未正确配置，请选择或配置其他模型"
            error.send(NSError(domain: "ImPollingChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            return
        }

        // Find the last failed bot message
        guard let lastFailedBotMessage = (currentChatSession.value.messages ?? []).last(where: { $0.sender == .bot && $0.status == .failed }) else {
            error.send(NSError(domain: "ImPollingChatViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "没有找到失败的请求"]))
            return
        }

        // Set the failed message back to sending status to show retry is happening
        var updatedMessages = currentChatSession.value.messages ?? []
        if let index = updatedMessages.firstIndex(where: { $0.id == lastFailedBotMessage.id }) {
            updatedMessages[index].status = .sending
            updatedMessages[index].content = ""
            updateChatSession(with: updatedMessages)
        }

        // Perform retry request with the selected model
        performChatRequest(with: finalModel, botMessageId: lastFailedBotMessage.id)
    }

    // Backward compatibility method
    func retryLastRequest()
    {
        retryLastRequest(with: nil)
    }

    // MARK: - Testing Support
    /// 用于单元测试的假数据注入方法
    func injectMockSession(_ session: ImPollingChatModel) {
        currentChatSession.send(session)
        messages.send(session.messages ?? [])
    }

    // MARK: - Lifecycle Management
    func setupLifecycleObservers() {
        guard notificationObservers.isEmpty else { return }

        // 1. LLM 模型变化观察者
        let modelObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "LLMModelDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let model = notification.object as? ImLLMModel {
                self._currentModelSubject.send(model)
                self.selectedModel = model
            } else {
                // 处理删除或清空默认模型的情况
                self._currentModelSubject.send(nil)
                self.selectedModel = nil
            }
        }

        // 2. 聊天会话选择观察者
        let sessionObserver = NotificationCenter.default.addObserver(
            forName: .didSelectChatSession,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let sessionId = notification.object as? String else { return }

            self.selectSession(withId: sessionId)
        }

        // 3. 聊天会话删除观察者（用于处理当前会话被删除的情况）
        let sessionDeleteObserver = NotificationCenter.default.addObserver(
            forName: .didDeleteChatSession,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let deletedSessionId = notification.object as? String,
                  let currentSessionId = self.currentChatSession.value.identifier,
                  String(currentSessionId) == deletedSessionId else { return }

            // 当前会话被删除，启动新会话
            self.startNewSession()
        }

        // 4. 应用进入后台观察者
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: .appDidEnterBackground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBackgroundEvent()
        }

        notificationObservers = [modelObserver, sessionObserver, sessionDeleteObserver, backgroundObserver]
    }

    func removeLifecycleObservers() {
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        notificationObservers.removeAll()
    }

    func loadDefaultModel() {
        ImDBHandler.share.queryFromDB(
            table: ImDBTableType.llmModel.description,
            cls: ImLLMModel.self
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let models):
                let defaultModel: ImLLMModel?
                if let model = models.first(where: { $0.isDefault == true }) {
                    defaultModel = model
                } else {
                    defaultModel = models.first
                }
                self._defaultModelLoadedSubject.send(defaultModel)
                self.selectedModel = defaultModel

            case .failure:
                self._defaultModelLoadedSubject.send(nil)
                self.selectedModel = nil
            }
        }
    }

    func getLLMButtonTitle(for model: ImLLMModel?) -> String {
        return model?.name ?? "选择模型"
    }

    func selectSession(withId sessionId: String) {
        loadSession(withId: sessionId)
    }

    func handleBackgroundEvent() {
        saveDraft()
    }

    deinit {
        removeLifecycleObservers()
    }
}
