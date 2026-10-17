//
//  ImPollingChatListViewModelProtocol.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 7/28/25.
//

import Foundation
import Combine

/// 轮询聊天列表专用操作结果
enum ImPollingChatListAction {
    case success(String)
    case errorOccurred(Error)
}

/// 轮询聊天列表ViewModel协议
protocol ImPollingChatListViewModelProtocol: ImBaseViewModel {
    // MARK: - 数据发布者
    var chatsPublisher: AnyPublisher<[ImPollingChatModel], Never> { get }
    var filterChatsPublisher: AnyPublisher<[ImPollingChatModel], Never> { get }
    var isFilterPublisher: AnyPublisher<Bool, Never> { get }
    var actionPublisher: AnyPublisher<ImPollingChatListAction, Never> { get }

    // MARK: - 数据属性
    var chatCount: Int { get }

    // MARK: - 业务方法
    func fetchChats()
    func getChat(at indexPath: IndexPath) -> ImPollingChatModel?
    func deleteChat(at indexPath: IndexPath)
    func updateChat(at indexPath: IndexPath, with chat: ImPollingChatModel)
    func indexPath(for chat: ImPollingChatModel) -> IndexPath?
    func updateStatusInFliter()
    func predicateChatSeriesDatas(filterText: String)

    // 会话历史相关方法
    func checkChatSessionExists(sessionId: Int, completion: @escaping (Bool, ImPollingChatModel?) -> Void)
}
