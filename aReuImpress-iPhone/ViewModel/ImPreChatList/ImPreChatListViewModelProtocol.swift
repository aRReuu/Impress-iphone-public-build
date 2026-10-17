//
//  ImPreChatListViewModelProtocol.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 7/28/25.
//

import Foundation
import Combine

/// 通用操作结果枚举
enum ImGenericAction {
    case loading(Bool)
    case success(String)
    case error(Error)
}

/// 预设聊天列表ViewModel协议
protocol ImPreChatListViewModelProtocol: ImBaseViewModel {
    // MARK: - 数据发布者
    var actionPublisher: AnyPublisher<ImGenericAction, Never> { get }
    var itemsPublisher: AnyPublisher<[ImPreChatModel], Never> { get }
    var filterPreChatsPublisher: AnyPublisher<[ImPreChatModel], Never> { get }
    var isFilterPublisher: AnyPublisher<Bool, Never> { get }

    // MARK: - 数据属性
    var itemCount: Int { get }

    // MARK: - 业务方法
    func getItem(at index: Int) -> ImPreChatModel?
    func insertItem(_ item: ImPreChatModel)
    func updateItem(_ item: ImPreChatModel)
    func deleteItem(at index: Int)
    func fetchPreChats()
    func createNewPreChat(question: String, content: String) -> ImPreChatModel
    func updateStatusInFilter()
    func predicatePreChatSeriesDatas(filterText: String)
}
