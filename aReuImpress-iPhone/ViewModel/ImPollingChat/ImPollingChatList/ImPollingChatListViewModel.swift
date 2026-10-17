//
//  ImPollingChatListViewModel.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 7/28/25.
//

import Foundation
import Combine
import WCDBSwift

/// 轮询聊天列表ViewModel实现
class ImPollingChatListViewModel: ImBaseViewModel, ImPollingChatListViewModelProtocol {
    // MARK: - Private Properties
    private let pollingChatTable = ImDBTableType.pollingChat.description
    private var cancellables = Set<AnyCancellable>()

    private let _chatsSubject = CurrentValueSubject<[ImPollingChatModel], Never>([])
    private let _filterChatsSubject = CurrentValueSubject<[ImPollingChatModel], Never>([])
    private let _isFilterSubject = CurrentValueSubject<Bool, Never>(false)
    private let _actionSubject = PassthroughSubject<ImPollingChatListAction, Never>()

    private var allChats: [ImPollingChatModel] = []
    private var filteredChats: [ImPollingChatModel] = []

    // MARK: - Public Publishers
    var chatsPublisher: AnyPublisher<[ImPollingChatModel], Never> {
        _chatsSubject.eraseToAnyPublisher()
    }

    var filterChatsPublisher: AnyPublisher<[ImPollingChatModel], Never> {
        _filterChatsSubject.eraseToAnyPublisher()
    }

    var isFilterPublisher: AnyPublisher<Bool, Never> {
        _isFilterSubject.eraseToAnyPublisher()
    }

    var actionPublisher: AnyPublisher<ImPollingChatListAction, Never> {
        _actionSubject.eraseToAnyPublisher()
    }

    // MARK: - Public Properties
    var chatCount: Int {
        _isFilterSubject.value ? filteredChats.count : allChats.count
    }

    // MARK: - Initialization
    override init() {
        super.init()
        setupBindings()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // 当isFilter改变时，更新发布者
        _isFilterSubject
            .sink { [weak self] isFiltering in
                guard let self = self else { return }
                if isFiltering {
                    self._filterChatsSubject.send(self.filteredChats)
                } else {
                    self._chatsSubject.send(self.allChats)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Protocol Methods
    func fetchChats() {
        ImDBHandler.share.queryFromDB(table: pollingChatTable,
                                      cls: ImPollingChatModel.self,
                                      where: ImPollingChatModel.Properties.title.isNotNull()) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let chats):
                    self.allChats = chats.sorted(by: { ($0.updateTime ?? Date.distantPast) > ($1.updateTime ?? Date.distantPast) })
                    self.updatePublishers()

                case .failure(let error):
                    self._actionSubject.send(.errorOccurred(error))
                }
            }
        }
    }

    func getChat(at indexPath: IndexPath) -> ImPollingChatModel? {
        let chats = _isFilterSubject.value ? filteredChats : allChats
        return indexPath.section >= 0 && indexPath.section < chats.count ? chats[indexPath.section] : nil
    }

    func updateChat(at indexPath: IndexPath, with chat: ImPollingChatModel) {
        guard let chatId = chat.identifier else {
            _actionSubject.send(.errorOccurred(NSError(domain: "ImPollingChatListViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "聊天ID为空"])))
            return
        }

        // 首先更新数据库
        dbShare.updateToDB(table: pollingChatTable, on: ImPollingChatModel.Properties.all, with: chat, where: ImPollingChatModel.Properties.identifier == chatId) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    // DB 更新成功后，更新内存数据
                    if let index = self.allChats.firstIndex(where: { $0.identifier == chatId }) {
                        self.allChats[index] = chat
                    }

                    if let index = self.filteredChats.firstIndex(where: { $0.identifier == chatId }) {
                        self.filteredChats[index] = chat
                    }

                    // Update publishers to refresh UI
                    self.updatePublishers()
                    self._actionSubject.send(.success("对话内容已更新"))

                    // 发送更新通知，让其他界面刷新
                    NotificationCenter.default.post(name: .didUpdateChatSession, object: String(chatId))

                case .failure(let error):
                    self._actionSubject.send(.errorOccurred(error))
                }
            }
        }
    }

    func deleteChat(at indexPath: IndexPath) {
        guard let chat = getChat(at: indexPath) else {
            _actionSubject.send(.errorOccurred(NSError(domain: "ImPollingChatListViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的索引"])))
            return
        }

        guard let chatId = chat.identifier else {
            _actionSubject.send(.errorOccurred(NSError(domain: "ImPollingChatListViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "聊天ID为空"])))
            return
        }

        dbShare.deleteFromTable(table: pollingChatTable,
                             where: ImPollingChatModel.Properties.identifier == chatId) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let chatIndex = self.allChats.firstIndex(where: { $0.identifier == chatId }) {
                        self.allChats.remove(at: chatIndex)
                    }

                    if let chatIndex = self.filteredChats.firstIndex(where: { $0.identifier == chatId }) {
                        self.filteredChats.remove(at: chatIndex)
                    }

                    self.updatePublishers()
                    self._actionSubject.send(.success("聊天记录删除成功"))

                    // 发送会话删除通知，让其他组件知道需要更新
                    NotificationCenter.default.post(name: .didDeleteChatSession, object: String(chatId))

                case .failure(let error):
                    self._actionSubject.send(.errorOccurred(error))
                }
            }
        }
    }

    func indexPath(for chat: ImPollingChatModel) -> IndexPath? {
        let chats = _isFilterSubject.value ? filteredChats : allChats
        if let index = chats.firstIndex(where: { $0.identifier == chat.identifier }) {
            return IndexPath(row: 0, section: index)
        }
        return nil
    }

    func updateStatusInFliter() {
        _isFilterSubject.send(false)
        filteredChats.removeAll()
    }

    func predicateChatSeriesDatas(filterText: String) {
        guard !filterText.isEmpty else {
            updateStatusInFliter()
            return
        }

        filteredChats = allChats.filter { chat in
            let titleMatch = chat.title?.localizedCaseInsensitiveContains(filterText) ?? false
            let subTitleMatch = chat.subTitle?.localizedCaseInsensitiveContains(filterText) ?? false

            // 检查消息内容
            let messagesMatch = chat.messages?.contains { message in
                message.content.localizedCaseInsensitiveContains(filterText)
            } ?? false

            return titleMatch || subTitleMatch || messagesMatch
        }

        _isFilterSubject.send(true)
    }

    // MARK: - 协议会话历史相关方法实现
    func checkChatSessionExists(sessionId: Int, completion: @escaping (Bool, ImPollingChatModel?) -> Void) {
        // 检查内存中的会话数据
        if let cachedChat = allChats.first(where: { $0.identifier == sessionId }) {
            completion(true, cachedChat)
            return
        }

        // 内存中不存在，从数据库查询
        ImDBHandler.share.queryOneObjectFromDB(
            table: pollingChatTable,
            cls: ImPollingChatModel.self,
            where: ImPollingChatModel.Properties.identifier == sessionId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let session):
                    completion(true, session)
                case .failure:
                    completion(false, nil)
                }
            }
        }
    }

    // MARK: - Private Helper Methods
    private func updatePublishers() {
        _chatsSubject.send(allChats)
        if _isFilterSubject.value {
            _filterChatsSubject.send(filteredChats)
        }
    }
}
