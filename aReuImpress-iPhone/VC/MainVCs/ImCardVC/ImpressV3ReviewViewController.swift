import UIKit
import ImpressReviewCore

/// An opt-in V3 pilot controller. It uses the EXISTING Tinder SwipeCardStack
/// and existing answer views, but delegates every grade to the durable V3 store.
@MainActor
final class ImpressV3ReviewViewController: UIViewController {
    private struct PendingSwipe {
        let cardID: UUID
        let index: Int
        var submission: ReviewSubmission?
        var visualFinished = false
        var sentAnimationAck = false
    }

    private let injectedRepository: ReviewWCDBRepository?
    private var repository: ReviewWCDBRepository?
    private var session: ReviewSessionCoordinator?
    private var items: [ReviewQueueItem] = []
    private var models: [UUID: ImCardModel] = [:]
    private var currentIndex = 0
    private var pending: PendingSwipe?
    private var isLoading = false
    private var hasLoaded = false

    private let cardStack = SwipeCardStack()
    private let revealButton = UIButton(type: .system)
    private let answerTools = UIStackView()
    private let statusLabel = UILabel()
    private let completionLabel = UILabel()
    private let repeatButton = UIButton(type: .system)
    private let busyIndicator = UIActivityIndicatorView(style: .medium)

    init(repository: ReviewWCDBRepository? = nil) {
        self.injectedRepository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(repository:) for V3 reviews")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "闪卡"
        view.backgroundColor = ImpressV3Appearance.page
        setupNativeLayout()
        setupNavigation()
        cardStack.numberOfVisibleCards = 3
        cardStack.protectsVerticalContentScroll = true
        // V3 tap is inert. Only explicit controls can create/edit a card.
        // Keep the existing Tinder pan and image-view tap untouched.
        cardStack.delegate = self
        cardStack.dataSource = self
        if !hasLoaded { reloadSession() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasLoaded && pending == nil { setRatingGesturesEnabled(canRateCurrentCard) }
    }

    private var canRateCurrentCard: Bool {
        guard pending == nil, currentIndex < items.count,
              let cardID = items[safe: currentIndex]?.cardID else { return false }
        if let view = cardStack.topCard?.content as? ImMemoryCardView {
            return view.answerIsRevealed && items[currentIndex].cardID == cardID
        }
        if let view = cardStack.topCard?.content as? ImMultipleChoiceCardView {
            return view.answerIsRevealed
        }
        return false
    }

    private func setupNativeLayout() {
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        revealButton.translatesAutoresizingMaskIntoConstraints = false
        answerTools.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        answerTools.axis = .horizontal
        answerTools.distribution = .fillEqually
        answerTools.spacing = ImpressV3Appearance.Metrics.rowSpacing
        answerTools.isHidden = true
        let reflect = UIButton(type: .system)
        reflect.setTitle("记录想法", for: .normal)
        reflect.titleLabel?.font = ImpressV3Appearance.Typography.supporting
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.secondary(reflect, title: "记录想法")
        }
        reflect.addTarget(self, action: #selector(captureFromAnswer), for: .touchUpInside)
        let explore = UIButton(type: .system)
        explore.setTitle("深入探讨", for: .normal)
        explore.titleLabel?.font = ImpressV3Appearance.Typography.supporting
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.secondary(explore, title: "深入探讨")
        }
        explore.accessibilityHint = "在 DeepSeek 网页继续讨论当前问题"
        explore.addTarget(self, action: #selector(exploreFromAnswer), for: .touchUpInside)
        let timeline = UIButton(type: .system)
        timeline.setTitle("历史", for: .normal)
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.secondary(timeline, title: "历史")
        }
        timeline.accessibilityLabel = "查看当前卡片的理解时间线"
        timeline.addTarget(self, action: #selector(openCurrentTimeline), for: .touchUpInside)
        answerTools.addArrangedSubview(reflect)
        answerTools.addArrangedSubview(explore)
        answerTools.addArrangedSubview(timeline)
        revealButton.setTitle("查看答案", for: .normal)
        revealButton.titleLabel?.font = ImpressV3Appearance.Typography.heading
        revealButton.titleLabel?.adjustsFontForContentSizeCategory = true
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.primary(revealButton, title: "查看答案")
        } else {
            revealButton.setTitleColor(ImpressV3Appearance.primaryButtonText, for: .normal)
            revealButton.backgroundColor = ImpressV3Appearance.accent
            revealButton.layer.cornerRadius = ImpressV3Appearance.Radius.field
        }
        revealButton.addTarget(self, action: #selector(revealCurrentAnswer),
                               for: .touchUpInside)
        revealButton.accessibilityHint = "显示答案后才可以通过四向滑动进行复习评分"
        revealButton.isHidden = true
        busyIndicator.translatesAutoresizingMaskIntoConstraints = false
        completionLabel.translatesAutoresizingMaskIntoConstraints = false
        repeatButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = ImpressV3Appearance.Typography.caption
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = ImpressV3Appearance.secondaryText
        statusLabel.textAlignment = .left
        statusLabel.text = "正在准备复习…"

        completionLabel.font = ImpressV3Appearance.Typography.body
        completionLabel.textColor = ImpressV3Appearance.secondaryText
        completionLabel.textAlignment = .center
        completionLabel.numberOfLines = 0
        completionLabel.isHidden = true

        repeatButton.setTitle("刷新到期卡片", for: .normal)
        ImpressV3Appearance.styleQuietButton(repeatButton, title: "刷新到期卡片")
        repeatButton.addTarget(self, action: #selector(refreshCards), for: .touchUpInside)
        repeatButton.isHidden = true

        view.addSubview(statusLabel)
        view.addSubview(cardStack)
        view.addSubview(revealButton)
        view.addSubview(answerTools)
        view.addSubview(busyIndicator)
        view.addSubview(completionLabel)
        view.addSubview(repeatButton)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cardStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            cardStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: revealButton.topAnchor, constant: -12),
            revealButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: ImpressV3Appearance.Metrics.screenInset),
            revealButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -ImpressV3Appearance.Metrics.screenInset),
            revealButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            revealButton.heightAnchor.constraint(greaterThanOrEqualToConstant: ImpressV3Appearance.Metrics.primaryActionHeight),
            answerTools.topAnchor.constraint(equalTo: revealButton.topAnchor),
            answerTools.leadingAnchor.constraint(equalTo: revealButton.leadingAnchor),
            answerTools.trailingAnchor.constraint(equalTo: revealButton.trailingAnchor),
            answerTools.bottomAnchor.constraint(equalTo: revealButton.bottomAnchor),
            busyIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            busyIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            completionLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            completionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            completionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            repeatButton.topAnchor.constraint(equalTo: completionLabel.bottomAnchor, constant: 20),
            repeatButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupNavigation() {
        // One creation menu, no misleading secondary chat/settings controls.
        let single = UIAction(title: "新建卡片",
                              image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
            self?.createCard()
        }
        let batch = UIAction(title: "批量导入",
                             image: UIImage(systemName: "square.stack.3d.up")) { [weak self] _ in
            self?.startBatchImport()
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"), menu: UIMenu(children: [single, batch]))
        navigationItem.leftBarButtonItem?.accessibilityLabel = "添加内容"
        updateNavigationActions()
    }

    private func updateNavigationActions() {
        // Settings has its own primary tab; no chat or gear action on review.
        navigationItem.rightBarButtonItems = nil
    }

    @objc private func openCurrentTimeline() {
        showUnderstandingTimeline()
    }

    private func displayFailure(_ error: Swift.Error) {
        let alert = UIAlertController(title: "复习操作未完成",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        if presentedViewController == nil { present(alert, animated: true) }
    }

    @objc private func refreshCards() { reloadSession() }

    private func reloadSession() {
        guard !isLoading, pending == nil else { return }
        isLoading = true
        hasLoaded = true
        statusLabel.text = "正在载入到期卡片…"
        cardStack.isUserInteractionEnabled = false
        busyIndicator.startAnimating()
        completionLabel.isHidden = true
        repeatButton.isHidden = true
        revealButton.isHidden = true
        answerTools.isHidden = true

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let repo = try self.injectedRepository ?? ImpressV3ReviewEnvironment.repository()
                let candidates = try await repo.fetchQueueCandidates()
                let queue = ReviewQueueBuilder.makeQueue(from: candidates, now: Date())
                var prepared: [UUID: ImCardModel] = [:]
                // At most six cards: read each image only when selected for THIS round.
                for selected in queue {
                    guard let row = try await repo.content(for: selected.cardID) else {
                        throw ReviewWCDBError.missingCard
                    }
                    var model = ImCardModel()
                    model.question = row.question
                    model.answer = row.answerText
                    model.cardType = row.cardType
                    model.imageData = row.imageData
                    model.choices = row.choices
                    model.correctAnswerIndices = row.correctIndices
                    prepared[selected.cardID] = model
                }
                self.repository = repo
                self.items = queue
                self.models = prepared
                self.currentIndex = 0
                self.pending = nil
                self.session = ReviewSessionCoordinator(items: queue, repository: repo)
                self.isLoading = false
                self.busyIndicator.stopAnimating()
                self.cardStack.reloadData() // ONLY for a fresh session, never per-swipe.
                self.showCurrent()
            } catch {
                self.isLoading = false
                self.busyIndicator.stopAnimating()
                self.cardStack.isHidden = true
                self.statusLabel.text = "无法读取 V3 复习数据"
                self.displayFailure(error)
            }
        }
    }

    private func showCurrent() {
        updateNavigationActions()
        guard currentIndex < items.count else {
            cardStack.isHidden = true
            completionLabel.isHidden = false
            repeatButton.isHidden = false
            revealButton.isHidden = true
            answerTools.isHidden = true
            completionLabel.text = items.isEmpty ? "暂无到期卡片，可以稍后再来。" :
                "本轮复习完成：\(items.count) 张"
            statusLabel.text = "本轮完成"
            return
        }
        cardStack.isHidden = false
        completionLabel.isHidden = true
        repeatButton.isHidden = true
        statusLabel.text = "第 \(currentIndex + 1) / \(items.count) 张 · 先回忆，再揭示答案"
        revealButton.isHidden = false
        answerTools.isHidden = true
        revealButton.isEnabled = true
        cardStack.isUserInteractionEnabled = true
        setRatingGesturesEnabled(false)
    }

    private func setRatingGesturesEnabled(_ enabled: Bool) {
        cardStack.shouldRecognizeHorizontalDrag = enabled
        cardStack.shouldRecognizeVerticalDrag = enabled
        cardStack.topCard?.panGestureRecognizer.isEnabled = enabled
    }

    private func answerChanged(cardID: UUID, revealed: Bool) {
        guard pending == nil, !isLoading,
              items[safe: currentIndex]?.cardID == cardID,
              let session = session else { return }
        Task {
            do {
                let phase = await session.phase()
                if revealed && phase == .question(cardID) {
                    try await session.revealAnswer(cardID: cardID)
                } else if !revealed && phase == .answer(cardID) {
                    try await session.hideAnswer(cardID: cardID)
                } else if (revealed && phase != .answer(cardID)) ||
                          (!revealed && phase != .question(cardID)) {
                    return
                }
                self.setRatingGesturesEnabled(revealed)
                self.revealButton.isHidden = revealed
                self.answerTools.isHidden = !revealed
                self.statusLabel.text = revealed
                    ? "左·困难   上·良好   右·简单   下·再次"
                    : "先回忆，再查看答案"
                self.updateNavigationActions()
            } catch {
                self.setRatingGesturesEnabled(false)
            }
        }
    }

    @objc private func revealCurrentAnswer() {
        guard !isLoading, pending == nil, currentIndex < items.count else { return }
        if let multiple = cardStack.topCard?.content as? ImMultipleChoiceCardView {
            multiple.showAnswer()
        } else if let standard = cardStack.topCard?.content as? ImMemoryCardView {
            standard.revealAnswerIfNeeded()
        }
    }

    @objc private func showMultiChoiceAnswer() {
        revealCurrentAnswer()
    }

    @objc private func captureFromAnswer() { captureUnderstanding() }

    @objc private func exploreFromAnswer() {
        guard let current = items[safe: currentIndex],
              let model = models[current.cardID],
              let question = model.question, !question.isEmpty else { return }

        // Explicit handoff to DeepSeek Web, NOT the separate native API chat.
        // Preparing clipboard text does not transmit a private question.
        // The user explicitly chooses when to copy/paste and send.
        let payload = ImpressV3DeepSeekHandoff.makePayload(
            question: question,
            answer: model.answer,
            userPrompt: UserDefaults.standard.string(forKey: "kSystemPrompt"))
        let web = ImWebViewController.forReviewHandoff(text: payload)
        navigationController?.pushViewController(web, animated: true)
        // The current ReviewSessionCoordinator/SwipeCardStack stays alive.
        // Navigating back must not grade or reload the current card.
    }

    private func captureUnderstanding() {
        let item = items[safe: currentIndex]
        let editor = ImpressV3CaptureViewController(
            cardID: item?.cardID, question: item.flatMap { models[$0.cardID]?.question } ?? "")
        let nav = UINavigationController(rootViewController: editor)
        if #available(iOS 15.0, *) {
            nav.sheetPresentationController?.detents = [.medium(), .large()]
        }
        present(nav, animated: true)
    }

    private func showUnderstandingTimeline() {
        let item = items[safe: currentIndex]
        let history = ImpressV3TimelineViewController(
            cardID: item?.cardID, repository: repository)
        navigationController?.pushViewController(history, animated: true)
    }

    private func startBatchImport() {
        guard pending == nil, !isLoading else { return }
        let importVC = ImpressV3BatchImportViewController()
        importVC.onCommit = { [weak self] inputs in
            guard let self else { throw CocoaError(.userCancelled) }
            let store = try self.repository ?? ImpressV3ReviewEnvironment.repository()
            let now = Date()
            let calculator = FSRS6ReviewCalculator()
            let entries = try inputs.map { input in
                (input: input, initial: try calculator.newCardSnapshot(id: input.cardID, now: now))
            }
            _ = try await store.insertBatchCards(entries, now: now)
            // Do not rewind a live review; new cards join a future session.
            if self.items.isEmpty, self.pending == nil, !self.isLoading {
                self.reloadSession()
            }
        }
        let navigation = ImNavigationViewController(rootViewController: importVC)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.large()]
        present(navigation, animated: true)
    }

    @objc private func createCard() {
        guard pending == nil, !isLoading else { return }
        // Dedicated V3 native editor. Legacy generic ImSubmit remains for
        // other callers; new cards use the same V3 WCDB and FSRS-6 authority.
        let composer = ImpressV3CardComposerViewController()
        composer.onSave = { [weak self] input in
            guard let self else { throw CocoaError(.userCancelled) }
            let store = try self.repository ?? ImpressV3ReviewEnvironment.repository()
            let now = Date()
            let initial = try FSRS6ReviewCalculator().newCardSnapshot(
                id: input.cardID, now: now)
            try await store.insertNewCard(input, initial: initial, now: now)
            // Never restart a live review or reveal/grade a card as a side
            // effect of creating content. Empty sessions may reload once.
            if self.items.isEmpty, self.pending == nil, !self.isLoading {
                self.reloadSession()
            }
        }
        let navigation = ImNavigationViewController(rootViewController: composer)
        navigation.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            navigation.sheetPresentationController?.detents = [.large()]
        }
        present(navigation, animated: true)
    }

    private func enableReminders() {
        ImpressV3NotificationCoordinator.shared.requestPermissionFromUserAction { [weak self] success in
            guard let self = self else { return }
            if success {
                ImpressV3NotificationCoordinator.shared.enableSmartReminders()
            } else {
                let alert = UIAlertController(title: "通知未授权",
                                              message: "可以在 iOS 设置中允许 Impress 的通知。",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func requestHabitReminders() {
        ImpressV3NotificationCoordinator.shared.requestPermissionFromUserAction { [weak self] success in
            guard let self = self else { return }
            if success {
                ImpressV3NotificationCoordinator.shared.enableHabitReminders()
            } else {
                let alert = UIAlertController(title: "通知未授权",
                                              message: "可以在 iOS 设置中允许 Impress 的通知。",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func acknowledgeAnimationIfReady() {
        guard var p = pending,
              p.visualFinished,
              !p.sentAnimationAck,
              let request = p.submission,
              let session = session else { return }
        p.sentAnimationAck = true
        pending = p
        Task {
            do {
                let effect = try await session.animationDidFinish(eventID: request.eventID)
                apply(effect)
            } catch {
                recoverUnexpectedError(error, cardID: request.cardID)
            }
        }
    }

    private func apply(_ effect: ReviewFlowEffect) {
        switch effect {
        case .none:
            return
        case let .showNext(expected):
            guard pending != nil else { return }
            currentIndex += 1
            pending = nil
            guard items[safe: currentIndex]?.cardID == expected else {
                reloadSession()
                return
            }
            showCurrent()
            ImpressV3NotificationCoordinator.shared.requestReconciliation()
        case .sessionCompleted:
            pending = nil
            currentIndex = items.count
            showCurrent()
            ImpressV3NotificationCoordinator.shared.requestReconciliation()
        case let .restoreCard(id):
            guard pending?.cardID == id else { return }
            // On failure, no rating was committed: use the component's native
            // undo without a second grading event. Only error path is nonanimated.
            cardStack.undoLastSwipe(animated: false)
            guard let session = session else { return }
            Task {
                do {
                    try await session.recoveryDidFinish(cardID: id)
                    pending = nil
                    cardStack.isUserInteractionEnabled = true
                    if let cardView = cardStack.topCard?.content as? ImMemoryCardView {
                        cardView.revealAnswerIfNeeded()
                    } else if let choicesView = cardStack.topCard?.content as? ImMultipleChoiceCardView {
                        choicesView.showAnswer()
                    }
                    setRatingGesturesEnabled(false) // Reveal callback re-enables after the animation.
                    statusLabel.text = "保存未成功，请重新滑动评分"
                    updateNavigationActions()
                } catch { recoverUnexpectedError(error, cardID: id) }
            }
        }
    }

    private func recoverUnexpectedError(_ error: Swift.Error, cardID: UUID) {
        pending = nil
        // If the coordinator and visual stack disagree, reload from the
        // durable database rather than risking a second grade for the wrong card.
        cardStack.isUserInteractionEnabled = false
        reloadSession()
        displayFailure(error)
    }
}

extension ImpressV3ReviewViewController: SwipeCardStackDataSource, SwipeCardStackDelegate {
    func numberOfCards(in cardStack: SwipeCardStack) -> Int {
        items.count
    }

    func cardStack(_ cardStack: SwipeCardStack, cardForIndexAt index: Int) -> SwipeCard {
        let card = SwipeCard()
        // The shared stack forwards top-card taps to its optional legacy
        // didSelect route. V3 must never interpret an answer tap as Create.
        card.tapGestureRecognizer.isEnabled = false
        card.swipeDirections = [.left, .up, .right, .down]
        for direction in card.swipeDirections {
            card.setOverlay(ImMemoryCardOverlay(direction: direction), forDirection: direction)
        }
        guard let item = items[safe: index], let model = models[item.cardID] else {
            return card
        }
        if model.cardType == CardType.multipleChoice.rawValue {
            let multiple = ImMultipleChoiceCardView(model: model, usesNativeOptionButtons: true)
            multiple.onAnswerRevealed = { [weak self] in
                self?.answerChanged(cardID: item.cardID, revealed: true)
            }
            card.content = multiple
        } else {
            let content = ImMemoryCardView(model: model, v3Style: true)
            content.onAnswerVisibilityChanged = { [weak self] revealed in
                self?.answerChanged(cardID: item.cardID, revealed: revealed)
            }
            if model.cardType == CardType.image.rawValue {
                content.onImageTapped = { [weak self] in
                    guard let self = self,
                          let data = model.imageData,
                          let image = UIImage(data: data) else { return }
                    self.setRatingGesturesEnabled(false)
                    self.present(ImImagePreviewViewController(
                        image: image, usesV3Appearance: true), animated: true)
                }
            }
            card.content = content
        }
        card.content?.backgroundColor = ImpressV3Appearance.surface
        card.backgroundColor = ImpressV3Appearance.surface
        card.layer.cornerRadius = ImpressV3Appearance.Radius.card
        card.clipsToBounds = true
        card.layer.borderWidth = 0
        return card
    }

    func cardStack(_ cardStack: SwipeCardStack,
                   didSwipeCardAt index: Int,
                   with direction: SwipeDirection) {
        guard !isLoading, pending == nil,
              let item = items[safe: index],
              index == currentIndex, let session = session else {
            cardStack.isUserInteractionEnabled = false
            return
        }
        let rating: ReviewRating
        switch direction {
        case .left: rating = .hard
        case .up: rating = .good
        case .right: rating = .easy
        case .down: rating = .again
        }
        let eventID = UUID()
        pending = PendingSwipe(cardID: item.cardID, index: index)
        cardStack.isUserInteractionEnabled = false
        setRatingGesturesEnabled(false)
        Task {
            do {
                let submission = try await session.beginSwipe(
                    cardID: item.cardID, rating: rating,
                    at: Date(), eventID: eventID
                )
                guard pending?.cardID == item.cardID else { return }
                pending?.submission = submission
                acknowledgeAnimationIfReady()
                let effect = try await session.commitPending(submission)
                apply(effect)
            } catch {
                recoverUnexpectedError(error, cardID: item.cardID)
            }
        }
    }

    func cardStack(_ cardStack: SwipeCardStack,
                   didFinishSwipeCardAt index: Int, with direction: SwipeDirection) {
        guard pending?.index == index else { return }
        pending?.visualFinished = true
        acknowledgeAnimationIfReady()
    }

    func didSwipeAllCards(_ cardStack: SwipeCardStack) {
        // Intentionally do nothing: the final ReviewEvent and animation must
        // BOTH be committed before ReviewSessionCoordinator emits completion.
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


// MARK: - V3.1 optional capture and understanding history
// Stored in a separate private, atomic journal. No legacy-card/FSRS schema
// changes, no Obsidian write, and cancelling NEVER creates a record.
struct ImpressV3LearningEntry: Codable, Equatable {
    let id: UUID
    let cardID: UUID?
    let question: String
    let userAnswer: String
    let createdAt: Date
    var aiEvaluation: String?
}

enum ImpressV3LearningJournal {
    private static let lock = NSRecursiveLock()
    private static func storeURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let path = base.appendingPathComponent("ImpressV3", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path.appendingPathComponent("LearningEntry-v1.json")
    }

    static func load() throws -> [ImpressV3LearningEntry] {
        lock.lock()
        defer { lock.unlock() }
        let path = try storeURL()
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        return try JSONDecoder().decode([ImpressV3LearningEntry].self,
                                        from: Data(contentsOf: path))
    }

    static func save(_ entry: ImpressV3LearningEntry) throws {
        lock.lock()
        defer { lock.unlock() }
        var records = try load()
        guard !records.contains(where: { $0.id == entry.id }) else { return }
        records.append(entry)
        try persist(records)
    }

    static func attachFeedback(_ feedback: String, to entryID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        var records = try load()
        guard let i = records.firstIndex(where: { $0.id == entryID }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        records[i].aiEvaluation = feedback
        try persist(records)
    }

    private static func persist(_ entries: [ImpressV3LearningEntry]) throws {
        let url = try storeURL()
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path)
        // WCDB/JSON Date round-trips may round fractional seconds. Compare
        // durable content and allow sub-millisecond Date precision differences.
        let verified = try JSONDecoder().decode(
            [ImpressV3LearningEntry].self, from: Data(contentsOf: url))
        guard verified.count == entries.count,
              zip(verified, entries).allSatisfy({ persisted, original in
                  persisted.id == original.id &&
                  persisted.cardID == original.cardID &&
                  persisted.question == original.question &&
                  persisted.userAnswer == original.userAnswer &&
                  persisted.aiEvaluation == original.aiEvaluation &&
                  abs(persisted.createdAt.timeIntervalSince(original.createdAt)) < 0.002
              }) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

@MainActor
final class ImpressV3CaptureViewController: UIViewController {
    private let cardID: UUID?
    private let question: String
    private let input = UITextView()
    var onSaved: (() -> Void)?

    init(cardID: UUID?, question: String) {
        self.cardID = cardID
        self.question = question
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(cardID:question:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "记录理解"
        view.backgroundColor = ImpressV3Appearance.page
        let subtitle = UILabel()
        subtitle.text = question.isEmpty ? "记录此刻的想法" : question
        subtitle.numberOfLines = 3
        subtitle.textColor = ImpressV3Appearance.secondaryText
        subtitle.font = ImpressV3Appearance.Typography.supporting
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        input.backgroundColor = ImpressV3Appearance.surface
        input.font = ImpressV3Appearance.Typography.body
        input.textColor = ImpressV3Appearance.primaryText
        input.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        input.layer.cornerRadius = ImpressV3Appearance.Radius.field
        input.translatesAutoresizingMaskIntoConstraints = false
        input.accessibilityLabel = "本次理解的文字记录"
        view.addSubview(subtitle)
        view.addSubview(input)
        NSLayoutConstraint.activate([
            subtitle.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            subtitle.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            subtitle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            input.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            input.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            input.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
        // The keyboard can cover most of a medium detent on small phones.
        // Allow the input to shrink rather than creating required conflicts.
        let minimumInput = input.heightAnchor.constraint(greaterThanOrEqualToConstant: 96)
        minimumInput.priority = .defaultLow
        minimumInput.isActive = true
        if #available(iOS 15.0, *) {
            input.bottomAnchor.constraint(
                equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12).isActive = true
        } else {
            input.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12).isActive = true
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "提交", style: .done, target: self, action: #selector(save))
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let value = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let entry = ImpressV3LearningEntry(id: UUID(), cardID: cardID,
            question: question, userAnswer: value, createdAt: Date(),
            aiEvaluation: nil)
        do {
            try ImpressV3LearningJournal.save(entry)
            dismiss(animated: true) { [weak self] in self?.onSaved?() }
        } catch {
            let alert = UIAlertController(title: "记录未保存",
                message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }
}

// The timeline is one chronological stream, not two ordinary list sections.
@MainActor
final class ImpressV3TimelineViewController: UITableViewController {
    private enum Event {
        case understanding(ImpressV3LearningEntry)
        case review(ReviewEvent)

        var time: Date {
            switch self {
            case .understanding(let entry): return entry.createdAt
            case .review(let event): return event.reviewedAt
            }
        }
    }
    private let cardID: UUID?
    private let repository: ReviewWCDBRepository?
    private var notes: [ImpressV3LearningEntry] = []
    private var reviewEvents: [ReviewEvent] = []
    private var ordered: [Event] {
        (notes.map { Event.understanding($0) } + reviewEvents.map { Event.review($0) })
            .sorted { a, b in a.time > b.time }
    }

    init(cardID: UUID?, repository: ReviewWCDBRepository?) {
        self.cardID = cardID
        self.repository = repository
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { fatalError("init(cardID:repository:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "理解时间线"
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 104
        tableView.register(ImpressV3TimelineNodeCell.self, forCellReuseIdentifier: "timeline.node")
        updateEmptyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadLearningHistory()
        if let cardID, let repo = repository {
            Task { [weak self] in
                do {
                    let result = try await repo.reviewHistory(for: cardID)
                    self?.reviewEvents = result
                    self?.tableView.reloadData()
                    self?.updateEmptyState()
                } catch {
                    // Do not modify WCDB or erase previously loaded cognition entries.
                    NSLog("Review history currently unavailable")
                }
            }
        }
    }

    private func reloadLearningHistory() {
        do {
            notes = try ImpressV3LearningJournal.load()
                .filter { cardID == nil || $0.cardID == cardID }
        } catch {
            let alert = UIAlertController(title: "读取历史失败",
                message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            if presentedViewController == nil { present(alert, animated: true) }
        }
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        let empty = UILabel()
        empty.font = ImpressV3Appearance.Typography.body
        empty.adjustsFontForContentSizeCategory = true
        empty.textColor = ImpressV3Appearance.secondaryText
        empty.numberOfLines = 0
        empty.textAlignment = .center
        empty.text = "还没有记录。\n回答、回顾和评价完成后会按时间展示在这里。"
        tableView.backgroundView = ordered.isEmpty ? empty : nil
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int { ordered.count }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "timeline.node", for: indexPath
        ) as? ImpressV3TimelineNodeCell else { return UITableViewCell() }
        switch ordered[indexPath.row] {
        case .understanding(let entry):
            cell.configure(time: entry.createdAt, title: "理解记录",
                           excerpt: entry.userAnswer,
                           footnote: entry.aiEvaluation == nil ? "未评价" : "含历史 AI 评价",
                           emphasized: true)
        case .review(let event):
            let rating: String
            switch event.rating {
            case .again: rating = "重来"
            case .hard: rating = "困难"
            case .good: rating = "良好"
            case .easy: rating = "容易"
            }
            cell.configure(time: event.reviewedAt, title: "复习 · " + rating,
                           excerpt: "FSRS-6 · 修订 \(event.before.revision) → \(event.after.revision)",
                           footnote: "真实评分事件", emphasized: false)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard ordered.indices.contains(indexPath.row) else { return }
        switch ordered[indexPath.row] {
        case .understanding(let entry):
            let detail = makeTextDetail(title: "理解记录", content:
                "题目\n" + entry.question + "\n\n本次理解\n" + entry.userAnswer +
                "\n\nAI 历史评价\n" + (entry.aiEvaluation ?? "尚未评价"))
            navigationController?.pushViewController(detail, animated: true)
        case .review(let event):
            let rating: String
            switch event.rating {
            case .again: rating = "重来"
            case .hard: rating = "困难"
            case .good: rating = "良好"
            case .easy: rating = "容易"
            }
            let date = DateFormatter()
            date.dateStyle = .medium
            date.timeStyle = .short
            let details = "评分\n" + rating +
                "\n\n发生时间\n" + date.string(from: event.reviewedAt) +
                "\n\n复习修订\n\(event.before.revision) → \(event.after.revision)" +
                "\n\n下一次到期\n" + date.string(from: event.after.dueAt)
            navigationController?.pushViewController(
                makeTextDetail(title: "复习记录", content: details), animated: true)
        }
    }

    private func makeTextDetail(title: String, content: String) -> UIViewController {
        let detail = UIViewController()
        detail.title = title
        detail.navigationItem.largeTitleDisplayMode = .never
        detail.view.backgroundColor = ImpressV3Appearance.page
        let body = UITextView()
        body.isEditable = false
        body.isSelectable = true
        body.font = ImpressV3Appearance.Typography.body
        body.adjustsFontForContentSizeCategory = true
        body.textColor = ImpressV3Appearance.primaryText
        body.backgroundColor = ImpressV3Appearance.surface
        body.layer.cornerRadius = ImpressV3Appearance.Radius.field
        body.text = content
        body.textContainerInset = UIEdgeInsets(top: ImpressV3Appearance.Metrics.fieldPadding, left: ImpressV3Appearance.Metrics.fieldPadding,
                                             bottom: ImpressV3Appearance.Metrics.fieldPadding, right: ImpressV3Appearance.Metrics.fieldPadding)
        body.translatesAutoresizingMaskIntoConstraints = false
        detail.view.addSubview(body)
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(
                equalTo: detail.view.safeAreaLayoutGuide.leadingAnchor, constant: ImpressV3Appearance.Metrics.screenInset),
            body.trailingAnchor.constraint(
                equalTo: detail.view.safeAreaLayoutGuide.trailingAnchor, constant: -ImpressV3Appearance.Metrics.screenInset),
            body.topAnchor.constraint(
                equalTo: detail.view.safeAreaLayoutGuide.topAnchor, constant: ImpressV3Appearance.Metrics.compactInset),
            body.bottomAnchor.constraint(
                equalTo: detail.view.safeAreaLayoutGuide.bottomAnchor, constant: -ImpressV3Appearance.Metrics.compactInset)
        ])
        return detail
    }
}

/// Native timeline rail, node and connected line; reusable and Dynamic Type-safe.
@MainActor
final class ImpressV3TimelineNodeCell: UITableViewCell {
    private let rail = UIView()
    private let dot = UIView()
    private let dateText = UILabel()
    private let titleText = UILabel()
    private let excerptText = UILabel()
    private let footnoteText = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessibilityIdentifier = "impress.v3.timeline.node"
        backgroundColor = ImpressV3Appearance.page
        contentView.backgroundColor = ImpressV3Appearance.page
        rail.translatesAutoresizingMaskIntoConstraints = false
        rail.backgroundColor = ImpressV3Appearance.divider
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = ImpressV3Appearance.Radius.timelineNode
        dateText.font = ImpressV3Appearance.Typography.caption
        dateText.textColor = ImpressV3Appearance.secondaryText
        titleText.font = ImpressV3Appearance.Typography.heading
        titleText.textColor = ImpressV3Appearance.primaryText
        excerptText.font = ImpressV3Appearance.Typography.supporting
        excerptText.textColor = ImpressV3Appearance.secondaryText
        excerptText.numberOfLines = 3
        footnoteText.font = ImpressV3Appearance.Typography.micro
        footnoteText.textColor = ImpressV3Appearance.mutedText
        for label in [dateText, titleText, excerptText, footnoteText] {
            label.adjustsFontForContentSizeCategory = true
            label.translatesAutoresizingMaskIntoConstraints = false
        }
        contentView.addSubview(rail)
        contentView.addSubview(dot)
        contentView.addSubview(dateText)
        contentView.addSubview(titleText)
        contentView.addSubview(excerptText)
        contentView.addSubview(footnoteText)
        NSLayoutConstraint.activate([
            rail.widthAnchor.constraint(equalToConstant: ImpressV3Appearance.Metrics.timelineRailWidth),
            rail.centerXAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ImpressV3Appearance.Metrics.timelineRailOffset),
            rail.topAnchor.constraint(equalTo: contentView.topAnchor),
            rail.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            dot.centerXAnchor.constraint(equalTo: rail.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: dateText.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: ImpressV3Appearance.Metrics.timelineDotDiameter),
            dot.heightAnchor.constraint(equalToConstant: ImpressV3Appearance.Metrics.timelineDotDiameter),
            dateText.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            dateText.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ImpressV3Appearance.Metrics.timelineTextOffset),
            dateText.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            titleText.topAnchor.constraint(equalTo: dateText.bottomAnchor, constant: 5),
            titleText.leadingAnchor.constraint(equalTo: dateText.leadingAnchor),
            titleText.trailingAnchor.constraint(equalTo: dateText.trailingAnchor),
            excerptText.topAnchor.constraint(equalTo: titleText.bottomAnchor, constant: 5),
            excerptText.leadingAnchor.constraint(equalTo: titleText.leadingAnchor),
            excerptText.trailingAnchor.constraint(equalTo: titleText.trailingAnchor),
            footnoteText.topAnchor.constraint(equalTo: excerptText.bottomAnchor, constant: 6),
            footnoteText.leadingAnchor.constraint(equalTo: excerptText.leadingAnchor),
            footnoteText.trailingAnchor.constraint(equalTo: excerptText.trailingAnchor),
            footnoteText.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
        accessoryType = .disclosureIndicator
        selectionStyle = .default
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    func configure(time: Date, title: String, excerpt: String,
                   footnote: String, emphasized: Bool) {
        let date = DateFormatter()
        date.dateStyle = .medium
        date.timeStyle = .short
        dateText.text = date.string(from: time)
        titleText.text = title
        excerptText.text = excerpt
        footnoteText.text = footnote
        dot.backgroundColor = emphasized ? ImpressV3Appearance.accent : ImpressV3Appearance.timelineInactive
        accessibilityLabel = (dateText.text ?? "") + "，" +
            title + "，" + excerpt + "，" + footnote
    }
}

// MARK: - R04.2-D settings as the third native tab

@MainActor
final class ImpressV3SettingsHubViewController: UITableViewController {
    private enum Destination {
        case promptLibrary, reminders
    }
    private struct Item {
        let title: String
        let detail: String
        let symbol: String
        let destination: Destination
    }
    private let groups: [(name: String, items: [Item])] = [
        ("内容工具", [
            Item(title: "提示词", detail: "费曼总结、选择题、问题与答案 · 可建立多份自定义模板",
                 symbol: "text.book.closed", destination: .promptLibrary)
        ]),
        ("学习节奏", [
            Item(title: "复习通知", detail: "关闭、到期提醒或每日习惯提醒",
                 symbol: "bell", destination: .reminders)
        ])
    ]

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        navigationItem.largeTitleDisplayMode = .always
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 66
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int { groups.count }
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        groups[section].items.count
    }
    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        groups[section].name
    }
    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        section == 0
            ? "本地模板在网页聊天中只会复制到剪贴板，不会自动发送私人笔记或内容。"
            : "本轮默认最多 6 张、新卡最多 3 张；每日上限和推送频次策略待单独审核，不在此版本擅自改变 FSRS。"
    }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = groups[indexPath.section].items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "setting")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "setting")
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.title
        content.secondaryText = item.detail
        content.secondaryTextProperties.numberOfLines = 2
        content.image = UIImage(systemName: item.symbol)
        content.imageProperties.tintColor = ImpressV3Appearance.secondaryText
        cell.contentConfiguration = content
        ImpressV3Appearance.styleGroupedCell(cell)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch groups[indexPath.section].items[indexPath.row].destination {
        case .promptLibrary:
            navigationController?.pushViewController(
                ImpressV3PromptLibraryViewController(), animated: true)
        case .reminders:
            navigationController?.pushViewController(
                ImpressV3ReminderSettingsController(), animated: true)
        }
    }
}

@MainActor
final class ImpressV3ReminderSettingsController: UITableViewController {
    private let labels = ["关闭提醒", "智能到期提醒 · 每天 09:00 起", "每日习惯提醒 · 09:00"]
    private let modeKey = "ImpressV3ReminderMode"

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "提醒通知"
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reminder")
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int { labels.count }

    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        "FSRS-6 决定到期时间；通知只负责提醒。智能提醒之间至少间隔 72 小时，关闭提醒不清除复习进度。"
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = labels[indexPath.row]
        cell.textLabel?.font = ImpressV3Appearance.Typography.body
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        ImpressV3Appearance.styleGroupedCell(cell)
        let mode = UserDefaults.standard.string(forKey: modeKey) ?? "off"
        let current = ["off", "smart", "habit"][indexPath.row]
        cell.accessoryType = mode == current ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            ImpressV3NotificationCoordinator.shared.disableReminders()
            tableView.reloadData()
            return
        }
        // iOS permission prompt must only follow an explicit user action.
        ImpressV3NotificationCoordinator.shared.requestPermissionFromUserAction {
            [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                let notice = UIAlertController(title: "通知未授权",
                    message: "可在 iOS 系统设置中允许通知；当前模式不会被强制修改。",
                    preferredStyle: .alert)
                notice.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(notice, animated: true)
                return
            }
            if indexPath.row == 1 {
                ImpressV3NotificationCoordinator.shared.enableSmartReminders()
            } else {
                ImpressV3NotificationCoordinator.shared.enableHabitReminders()
            }
            self.tableView.reloadData()
        }
    }
}
