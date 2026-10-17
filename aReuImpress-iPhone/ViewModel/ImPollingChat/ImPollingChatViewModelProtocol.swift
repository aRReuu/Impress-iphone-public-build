import Foundation
import Combine

// MARK: - Data Structures
struct TokenUsageInfo {
    let currentTokens: Int
    let maxTokens: Int
}

// 简化的聊天ViewModel协议 - 合并Input和Output，避免复杂性
protocol ImPollingChatViewModelType {
    // MARK: - 数据输出
    var currentChatSession: CurrentValueSubject<ImPollingChatModel, Never> { get }
    var messages: CurrentValueSubject<[ImPollingChatMessage], Never> { get }
    var scrollToIndexPath: PassthroughSubject<IndexPath, Never> { get }
    var showMenuForCell: PassthroughSubject<IndexPath, Never> { get }
    var presetQuestions: CurrentValueSubject<[String], Never> { get }
    var newSessionDidStart: PassthroughSubject<Void, Never> { get }
    var showAssistMenuPublisher: PassthroughSubject<Void, Never> { get }
    var isLoading: PassthroughSubject<Bool, Never> { get }
    var error: PassthroughSubject<Error, Never> { get }
    var tokenUsage: CurrentValueSubject<TokenUsageInfo?, Never> { get }

    // MARK: - 生命周期管理发布者
    var currentModelPublisher: AnyPublisher<ImLLMModel?, Never> { get }
    var backgroundEventPublisher: AnyPublisher<Void, Never> { get }
    var sessionSelectionPublisher: AnyPublisher<String, Never> { get }
    var defaultModelLoadedPublisher: AnyPublisher<ImLLMModel?, Never> { get }

    // MARK: - 业务方法
    func feynmanConcluded(with updatedSession: ImPollingChatModel)
    func sendMessage(_ content: String, with model: ImLLMModel?)
    func deleteMessage(at indexPath: IndexPath)
    func search(with query: String)
    func showNextSearchResult()
    func showPreviousSearchResult()
    func longPressCell(at indexPath: IndexPath)
    func triggerAssistMenu()
    func fetchPresetQuestions()
    func startNewSession()
    func loadSession(withId sessionId: String)
    func saveDraft()
    func retryLastRequest(with model: ImLLMModel?)

    // MARK: - 下划线管理方法
    func addUnderline(toMessageWithId messageId: UUID, range: NSRange, text: String)
    func removeUnderline(fromMessageWithId messageId: UUID, underlineId: UUID)

    // MARK: - 生命周期管理方法
    func setupLifecycleObservers()
    func removeLifecycleObservers()
    func loadDefaultModel()
    func getLLMButtonTitle(for model: ImLLMModel?) -> String
    func selectSession(withId sessionId: String)
    func handleBackgroundEvent()

    // MARK: - 测试支持
    func injectMockSession(_ session: ImPollingChatModel)
}
