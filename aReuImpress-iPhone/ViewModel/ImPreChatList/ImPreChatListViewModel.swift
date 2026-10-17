//
//  ImPreChatListViewModel.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 7/28/25.
//

import Foundation
import Combine
import WCDBSwift

/// 预设聊天列表ViewModel实现
class ImPreChatListViewModel: ImBaseViewModel, ImPreChatListViewModelProtocol {
    // MARK: - Private Properties
    private let preChatTable = ImDBTableType.preChat.description
    private var cancellables = Set<AnyCancellable>()

    private let _actionSubject = PassthroughSubject<ImGenericAction, Never>()
    private let _itemsSubject = CurrentValueSubject<[ImPreChatModel], Never>([])
    private let _filterPreChatsSubject = CurrentValueSubject<[ImPreChatModel], Never>([])
    private let _isFilterSubject = CurrentValueSubject<Bool, Never>(false)

    private var allItems: [ImPreChatModel] = []
    private var filteredItems: [ImPreChatModel] = []

    // MARK: - Public Publishers
    var actionPublisher: AnyPublisher<ImGenericAction, Never> {
        _actionSubject.eraseToAnyPublisher()
    }

    var itemsPublisher: AnyPublisher<[ImPreChatModel], Never> {
        _itemsSubject.eraseToAnyPublisher()
    }

    var filterPreChatsPublisher: AnyPublisher<[ImPreChatModel], Never> {
        _filterPreChatsSubject.eraseToAnyPublisher()
    }

    var isFilterPublisher: AnyPublisher<Bool, Never> {
        _isFilterSubject.eraseToAnyPublisher()
    }

    // MARK: - Public Properties
    var itemCount: Int {
        _isFilterSubject.value ? filteredItems.count : allItems.count
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
                    self._filterPreChatsSubject.send(self.filteredItems)
                } else {
                    self._itemsSubject.send(self.allItems)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Protocol Methods
    func getItem(at index: Int) -> ImPreChatModel? {
        let items = _isFilterSubject.value ? filteredItems : allItems
        return index >= 0 && index < items.count ? items[index] : nil
    }

    func insertItem(_ item: ImPreChatModel) {
        _actionSubject.send(.loading(true))

        dbShare.insertToDB(intoTable: preChatTable, with: [item]) {[weak self] result in
            guard let self = self else{return}
            self._actionSubject.send(.loading(false))
            switch result {
            case .success:
                self.allItems.append(item)
                self.updatePublishers()
                self._actionSubject.send(.success("标记问题创建成功"))
                NotificationCenter.default.post(name: .didUpdatePreChatList, object: nil)
                break
            case .failure(let error):
                self._actionSubject.send(.error(error))
                break
            }
        }
    }

    func updateItem(_ item: ImPreChatModel) {
        _actionSubject.send(.loading(true))

        dbShare.updateToDB(table: preChatTable,
                          on: ImPreChatModel.Properties.all,
                          with: item,
                          where: ImPreChatModel.Properties.identifier == item.identifier!) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self.allItems.firstIndex(where: { $0.identifier == item.identifier }) {
                        self.allItems[index] = item
                        self.updatePublishers()
                    }

                    if let index = self.filteredItems.firstIndex(where: { $0.identifier == item.identifier }) {
                        self.filteredItems[index] = item
                        if self._isFilterSubject.value {
                            self._filterPreChatsSubject.send(self.filteredItems)
                        }
                    }

                    self._actionSubject.send(.success("标记问题更新成功"))
                    NotificationCenter.default.post(name: .didUpdatePreChatList, object: nil)

                case .failure(let error):
                    self._actionSubject.send(.error(error))
                }

                self._actionSubject.send(.loading(false))
            }
        }
    }

    func deleteItem(at index: Int) {
        guard let item = getItem(at: index) else { return }

        _actionSubject.send(.loading(true))

        dbShare.deleteFromTable(table: preChatTable,
                               where: ImPreChatModel.Properties.identifier == item.identifier!) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let itemIndex = self.allItems.firstIndex(where: { $0.identifier == item.identifier }) {
                        self.allItems.remove(at: itemIndex)
                    }

                    if let itemIndex = self.filteredItems.firstIndex(where: { $0.identifier == item.identifier }) {
                        self.filteredItems.remove(at: itemIndex)
                    }

                    self.updatePublishers()
                    self._actionSubject.send(.success("标记问题删除成功"))
                    NotificationCenter.default.post(name: .didUpdatePreChatList, object: nil)

                case .failure(let error):
                    self._actionSubject.send(.error(error))
                }

                self._actionSubject.send(.loading(false))
            }
        }
    }

    func fetchPreChats() {
        _actionSubject.send(.loading(true))

        ImDBHandler.share.queryFromDB(table: preChatTable,
                                    cls: ImPreChatModel.self,
                                    orderBy: [ImPreChatModel.Properties.updateTime.asOrder(by: .descending)]) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.allItems = items
                    self.updatePublishers()
                    NotificationCenter.default.post(name: .didUpdatePreChatList, object: nil)

                case .failure(let error):
                    self._actionSubject.send(.error(error))
                }
                self._actionSubject.send(.loading(false))
            }
        }
    }

    func createNewPreChat(question: String, content: String) -> ImPreChatModel {
        var newItem = ImPreChatModel()
        newItem.question = question
        newItem.content = content
        newItem.updateTime = Date()
        newItem.isChated = false
        return newItem
    }

    func updateStatusInFilter() {
        _isFilterSubject.send(false)
        filteredItems.removeAll()
    }

    func predicatePreChatSeriesDatas(filterText: String) {
        guard !filterText.isEmpty else {
            updateStatusInFilter()
            return
        }

        filteredItems = allItems.filter { item in
            let questionMatch = item.question?.localizedCaseInsensitiveContains(filterText) ?? false
            let contentMatch = item.content?.localizedCaseInsensitiveContains(filterText) ?? false
            let sourceMatch = item.questionSource?.localizedCaseInsensitiveContains(filterText) ?? false
            return questionMatch || contentMatch || sourceMatch
        }

        _isFilterSubject.send(true)
    }

    // MARK: - Private Helper Methods
    private func updatePublishers() {
        _itemsSubject.send(allItems)
        if _isFilterSubject.value {
            _filterPreChatsSubject.send(filteredItems)
        }
    }
}
