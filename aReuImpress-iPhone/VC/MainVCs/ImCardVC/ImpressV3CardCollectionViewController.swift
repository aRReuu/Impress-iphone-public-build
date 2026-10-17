import UIKit

/// V3-only management surface. Reviews still use SwipeCardStack/FSRS;
/// this page owns explicit CRUD actions on the same WCDB actor.
@MainActor
final class ImpressV3CardCollectionViewController: UITableViewController, UISearchResultsUpdating {
    var onMutation: (() -> Void)?

    private let repository: ReviewWCDBRepository
    private let searchController = UISearchController(searchResultsController: nil)
    private var cards: [WCDBV3ManagedCard] = []
    private var generation = 0
    private var loading = false
    private var hasMore = true
    private let pageSize = 80

    init(repository: ReviewWCDBRepository) {
        self.repository = repository
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(repository:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "卡片集"
        navigationItem.largeTitleDisplayMode = .always
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72

        searchController.searchBar.placeholder = "搜索问题、答案、来源"
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"), style: .plain,
            target: self, action: #selector(createCard))
        reloadCards()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A returned editor may have changed content; never show a stale row.
        if isViewLoaded { reloadCards() }
    }

    func updateSearchResults(for searchController: UISearchController) {
        reloadCards()
    }

    private func reloadCards() {
        generation += 1
        loading = false
        hasMore = true
        cards.removeAll()
        tableView.reloadData()
        loadMore()
    }

    private func loadMore() {
        guard !loading, hasMore else { return }
        loading = true
        let ticket = generation
        let offset = cards.count
        let query = searchController.searchBar.text ?? ""
        Task { [weak self] in
            guard let self else { return }
            do {
                let next = try await repository.listManagedCards(
                    matching: query, offset: offset, limit: pageSize)
                guard ticket == generation else { return }
                loading = false
                hasMore = next.count == pageSize
                cards.append(contentsOf: next)
                tableView.reloadData()
                updateEmptyView()
            } catch {
                guard ticket == generation else { return }
                loading = false
                hasMore = false
                showError(error)
                updateEmptyView()
            }
        }
    }

    private func updateEmptyView() {
        guard cards.isEmpty && !loading else {
            tableView.backgroundView = nil
            return
        }
        let label = UILabel()
        label.text = searchController.searchBar.text?.isEmpty == false
            ? "没有找到匹配的卡片"
            : "暂无卡片，点击右上角新建"
        label.textColor = ImpressV3Appearance.secondaryText
        label.textAlignment = .center
        label.font = ImpressV3Appearance.Typography.supporting
        label.numberOfLines = 0
        tableView.backgroundView = label
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        cards.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = cards[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "managed-card")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "managed-card")
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.question
        let kind: String
        let symbol: String
        switch item.cardType {
        case CardType.multipleChoice.rawValue:
            kind = "选择题"; symbol = "list.bullet.rectangle"
        case CardType.image.rawValue:
            kind = "图片"; symbol = "photo"
        default:
            kind = "问答"; symbol = "text.book.closed"
        }
        let status = item.isSuspended ? "已暂停" : "参与复习"
        content.secondaryText = [kind, status, item.sourceNotePath]
            .compactMap { $0 }.joined(separator: " · ")
        content.textProperties.numberOfLines = 2
        content.secondaryTextProperties.numberOfLines = 2
        content.image = UIImage(systemName: symbol)
        content.imageProperties.tintColor = ImpressV3Appearance.secondaryText
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        ImpressV3Appearance.styleGroupedCell(cell)
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            willDisplay cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        if indexPath.row >= cards.count - 8 { loadMore() }
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard cards.indices.contains(indexPath.row) else { return }
        editCard(cards[indexPath.row])
    }

    @objc private func createCard() {
        let composer = ImpressV3CardComposerViewController()
        composer.onSave = { [weak self] input in
            guard let self else { throw CocoaError(.userCancelled) }
            let now = Date()
            let initial = try FSRS6ReviewCalculator().newCardSnapshot(
                id: input.cardID, now: now)
            try await repository.insertNewCard(input, initial: initial, now: now)
            onMutation?()
            reloadCards()
        }
        showComposer(composer)
    }

    private func editCard(_ item: WCDBV3ManagedCard) {
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let stored = try await repository.content(for: item.cardID) else {
                    throw ReviewWCDBError.missingCard
                }
                let selections = Set((stored.correctIndices ?? "")
                    .split(separator: ",").compactMap { Int($0) })
                let choices: [ImpressV3CardDraft.Choice] =
                    (stored.choices ?? "").isEmpty
                    ? [ImpressV3CardDraft.Choice(), ImpressV3CardDraft.Choice()]
                    : (stored.choices ?? "").components(separatedBy: "\n")
                        .enumerated().map { index, value in
                            ImpressV3CardDraft.Choice(
                                text: value, isCorrect: selections.contains(index))
                        }
                let draft = ImpressV3CardDraft(
                    kind: CardType(rawValue: stored.cardType) ?? .standard,
                    question: stored.question,
                    answer: stored.answerText ?? "",
                    choices: choices,
                    allowsMultipleCorrect: selections.count > 1,
                    imageData: stored.imageData,
                    sourceNotePath: stored.sourceNotePath)
                let editor = ImpressV3CardComposerViewController(
                    draft: draft, editingCardID: item.cardID)
                editor.onSave = { [weak self] input in
                    guard let self else { throw CocoaError(.userCancelled) }
                    try await repository.updateManagedCard(
                        input, expectedRevision: item.revision)
                    onMutation?()
                    reloadCards()
                }
                showComposer(editor)
            } catch { showError(error) }
        }
    }

    private func showComposer(_ composer: ImpressV3CardComposerViewController) {
        let navigation = ImNavigationViewController(rootViewController: composer)
        navigation.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            navigation.sheetPresentationController?.detents = [.large()]
        }
        present(navigation, animated: true)
    }

    private func changeSuspension(_ item: WCDBV3ManagedCard) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.setManagedCardSuspended(
                    !item.isSuspended, id: item.cardID,
                    expectedRevision: item.revision)
                onMutation?()
                reloadCards()
            } catch { showError(error) }
        }
    }

    private func confirmDelete(_ item: WCDBV3ManagedCard) {
        let alert = UIAlertController(
            title: "永久删除卡片？",
            message: "这将同时删除该卡片的 FSRS 复习事件。外部 Obsidian 原始笔记不会被修改。",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) {
            [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    try await repository.deleteManagedCard(
                        id: item.cardID, expectedRevision: item.revision)
                    onMutation?()
                    reloadCards()
                } catch { showError(error) }
            }
        })
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard cards.indices.contains(indexPath.row) else { return nil }
        let item = cards[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "删除") {
            [weak self] _, _, finish in
            self?.confirmDelete(item)
            finish(false)
        }
        let pause = UIContextualAction(style: .normal,
            title: item.isSuspended ? "恢复" : "暂停") {
            [weak self] _, _, finish in
            self?.changeSuspension(item)
            finish(true)
        }
        let result = UISwipeActionsConfiguration(actions: [delete, pause])
        result.performsFirstActionWithFullSwipe = false
        return result
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "操作未完成",
            message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        if presentedViewController == nil { present(alert, animated: true) }
    }
}
