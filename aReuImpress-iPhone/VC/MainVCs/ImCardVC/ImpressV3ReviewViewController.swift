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
        view.backgroundColor = bgColor
        setupNativeLayout()
        setupNavigation()
        cardStack.numberOfVisibleCards = 3
        cardStack.protectsVerticalContentScroll = true
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
        answerTools.spacing = 10
        answerTools.isHidden = true
        let reflect = UIButton(type: .system)
        reflect.setTitle("记录想法", for: .normal)
        reflect.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.secondary(reflect, title: "记录想法")
        }
        reflect.addTarget(self, action: #selector(captureFromAnswer), for: .touchUpInside)
        let explore = UIButton(type: .system)
        explore.setTitle("深入探讨", for: .normal)
        explore.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.secondary(explore, title: "深入探讨")
        }
        explore.accessibilityHint = "在 DeepSeek 网页继续讨论当前问题"
        explore.addTarget(self, action: #selector(exploreFromAnswer), for: .touchUpInside)
        answerTools.addArrangedSubview(reflect)
        answerTools.addArrangedSubview(explore)
        revealButton.setTitle("查看答案", for: .normal)
        revealButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        revealButton.titleLabel?.adjustsFontForContentSizeCategory = true
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.primary(revealButton, title: "查看答案")
        } else {
            revealButton.setTitleColor(.white, for: .normal)
            revealButton.backgroundColor = .systemBlue
            revealButton.layer.cornerRadius = 14
        }
        revealButton.addTarget(self, action: #selector(revealCurrentAnswer),
                               for: .touchUpInside)
        revealButton.accessibilityHint = "显示答案后才可以通过四向滑动进行复习评分"
        revealButton.isHidden = true
        busyIndicator.translatesAutoresizingMaskIntoConstraints = false
        completionLabel.translatesAutoresizingMaskIntoConstraints = false
        repeatButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .left
        statusLabel.text = "正在准备复习…"
        statusLabel.font = UIFont.preferredFont(forTextStyle: .caption1)

        completionLabel.font = UIFont.preferredFont(forTextStyle: .body)
        completionLabel.textColor = .secondaryLabel
        completionLabel.textAlignment = .center
        completionLabel.numberOfLines = 0
        completionLabel.isHidden = true

        repeatButton.setTitle("刷新到期卡片", for: .normal)
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.secondary(repeatButton, title: "刷新到期卡片")
        }
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
            revealButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            revealButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            revealButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            revealButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(createCard)
        )
        updateNavigationActions()
    }

    private func updateNavigationActions() {
        // Keep the primary menu short. Low-frequency notifications and
        // model administration belong in native submenus / settings.
        let capture = UIAction(title: "记录理解",
                               image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
            self?.captureUnderstanding()
        }
        let timeline = UIAction(title: "理解时间线",
                                image: UIImage(systemName: "clock.arrow.circlepath")) { [weak self] _ in
            self?.showUnderstandingTimeline()
        }

        let nativeChat = UIAction(title: "AI 问答（API）",
                                  image: UIImage(systemName: "bubble.left.and.bubble.right")) { [weak self] _ in
            let chat = ImPollingChatViewController()
            chat.title = "AI 问答"
            self?.navigationController?.pushViewController(chat, animated: true)
        }
        let deepSeek = UIAction(title: "DeepSeek 网页",
                                image: UIImage(systemName: "globe")) { [weak self] _ in
            self?.exploreFromAnswer()
        }
        let models = UIAction(title: "模型配置",
                              image: UIImage(systemName: "cpu")) { [weak self] _ in
            self?.present(ImNavigationViewController(
                rootViewController: ImLLMConfigViewController()), animated: true)
        }
        let aiMenu = UIMenu(title: "AI 工具",
                            image: UIImage(systemName: "sparkles"),
                            children: [nativeChat, deepSeek, models])

        let refresh = UIAction(title: "刷新复习队列",
                               image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
            self?.reloadSession()
        }
        let notifications = UIAction(title: "提醒设置",
                                     image: UIImage(systemName: "bell")) { [weak self] _ in
            self?.navigationController?.pushViewController(
                ImpressV3ReminderSettingsController(), animated: true)
        }
        var reviewActions: [UIMenuElement] = [refresh, notifications]
        #if DEBUG
        reviewActions.append(UIAction(
            title: "下次启动恢复旧版闪卡（测试）",
            image: UIImage(systemName: "arrow.uturn.backward")) { _ in
            ImpressV3ReviewEnvironment.pilotEnabled = false
            ImpressV3NotificationCoordinator.shared.disableReminders()
        })
        #endif
        let reviewMenu = UIMenu(title: "复习与提醒",
                                image: UIImage(systemName: "rectangle.stack"),
                                children: reviewActions)

        let settings = UIAction(title: "设置",
                                image: UIImage(systemName: "gearshape")) { [weak self] _ in
            self?.navigationController?.pushViewController(
                ImpressV3SettingsHubViewController(), animated: true)
        }
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                   style: .plain, target: nil, action: nil)
        more.menu = UIMenu(children: [capture, timeline, aiMenu, reviewMenu, settings])
        navigationItem.rightBarButtonItem = more
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

    @objc private func createCard() {
        guard pending == nil, !isLoading else { return }
        let submit = ImSubmitViewController(submitModel: ImCardModel())
        submit.submitActionResult = { [weak self] card in
            guard let self = self else { return }
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    let repo = try self.repository ?? ImpressV3ReviewEnvironment.repository()
                    let id = UUID()
                    let now = Date()
                    let initial = try FSRS6ReviewCalculator().newCardSnapshot(id: id, now: now)
                    let input = WCDBV3CardInput(
                        cardID: id,
                        question: card.question ?? "",
                        answerText: card.answer,
                        choices: card.choices,
                        correctIndices: card.correctAnswerIndices,
                        cardType: card.cardType ?? 0,
                        imageData: card.imageData
                    )
                    try await repo.insertNewCard(input, initial: initial, now: now)
                    if self.pending == nil { self.reloadSession() }
                } catch {
                    self.displayFailure(error)
                }
            }
        }
        present(submit, animated: true)
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
                    self.present(ImImagePreviewViewController(image: image), animated: true)
                }
            }
            card.content = content
        }
        card.content?.backgroundColor = UIColor.systemBackground
        card.layer.cornerRadius = 19
        card.clipsToBounds = true
        card.layer.borderWidth = 0.6
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
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
        view.backgroundColor = .systemGroupedBackground
        let subtitle = UILabel()
        subtitle.text = question.isEmpty ? "记录此刻的想法" : question
        subtitle.numberOfLines = 3
        subtitle.textColor = .secondaryLabel
        subtitle.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        input.backgroundColor = .secondarySystemGroupedBackground
        input.font = UIFont.preferredFont(forTextStyle: .body)
        input.textColor = .label
        input.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        input.layer.cornerRadius = 14
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

@MainActor
final class ImpressV3TimelineViewController: UITableViewController {
    private let cardID: UUID?
    private let repository: ReviewWCDBRepository?
    private var notes: [ImpressV3LearningEntry] = []
    private var reviewEvents: [ReviewEvent] = []

    init(cardID: UUID?, repository: ReviewWCDBRepository?) {
        self.cardID = cardID
        self.repository = repository
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(cardID:repository:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "理解时间线"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "timeline")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadLearningHistory()
        if let cardID = cardID, let repo = repository {
            Task { [weak self] in
                do {
                    let history = try await repo.reviewHistory(for: cardID)
                    self?.reviewEvents = history.sorted { $0.reviewedAt > $1.reviewedAt }
                    self?.tableView.reloadData()
                } catch {
                    // Journal remains readable when the FSRS database is busy.
                    NSLog("Review history unavailable: %@", error.localizedDescription)
                }
            }
        }
    }

    private func reloadLearningHistory() {
        do {
            notes = try ImpressV3LearningJournal.load()
                .filter { cardID == nil || $0.cardID == cardID }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            let alert = UIAlertController(title: "读取历史失败",
                message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            if presentedViewController == nil { present(alert, animated: true) }
        }
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        section == 0 ? notes.count : reviewEvents.count
    }
    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "逐版理解记录" : "FSRS 真实复习记录"
    }
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 3
        cell.detailTextLabel?.numberOfLines = 2
        let date = DateFormatter()
        date.dateStyle = .short
        date.timeStyle = .short
        if indexPath.section == 0 {
            let note = notes[indexPath.row]
            cell.textLabel?.text = note.userAnswer
            cell.detailTextLabel?.text = date.string(from: note.createdAt) +
                (note.aiEvaluation == nil ? " · 尚未获得 AI 评价" : " · 有 AI 评价")
            cell.accessoryType = .disclosureIndicator
        } else {
            let event = reviewEvents[indexPath.row]
            let name: String
            switch event.rating {
            case .again: name = "再次"
            case .hard: name = "困难"
            case .good: name = "良好"
            case .easy: name = "简单"
            }
            cell.textLabel?.text = name
            cell.detailTextLabel?.text = date.string(from: event.reviewedAt)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else { return }
        let entry = notes[indexPath.row]
        let detail = UIViewController()
        detail.title = "理解记录"
        detail.view.backgroundColor = .systemBackground
        let body = UITextView()
        body.isEditable = false
        body.font = UIFont.preferredFont(forTextStyle: .body)
        body.text = "题目：\n" + entry.question + "\n\n本次回答：\n" +
            entry.userAnswer + "\n\nAI 反馈：\n" + (entry.aiEvaluation ?? "尚未评价")
        body.translatesAutoresizingMaskIntoConstraints = false
        detail.view.addSubview(body)
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.trailingAnchor),
            body.topAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.topAnchor),
            body.bottomAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        if entry.aiEvaluation == nil {
            detail.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "AI 评价", style: .plain, target: nil, action: nil)
            detail.navigationItem.rightBarButtonItem?.primaryAction = UIAction { [weak self, weak detail] _ in
                self?.requestExplicitAIEvaluation(entry, detail: detail)
            }
        }
        navigationController?.pushViewController(detail, animated: true)
    }

    private func requestExplicitAIEvaluation(_ entry: ImpressV3LearningEntry,
                                             detail: UIViewController?) {
        let confirmation = UIAlertController(
            title: "向 AI 模型发送这次理解？",
            message: "将把本条题目和你的回答发送到当前配置的外部 AI 服务。未经确认不会上传 Obsidian 内容。",
            preferredStyle: .alert)
        confirmation.addAction(UIAlertAction(title: "取消", style: .cancel))
        confirmation.addAction(UIAlertAction(title: "同意并评价", style: .default) { [weak self] _ in
            self?.evaluate(entry, detail: detail)
        })
        present(confirmation, animated: true)
    }

    private func evaluate(_ entry: ImpressV3LearningEntry, detail: UIViewController?) {
        dbShare.queryFromDB(table: ImDBTableType.llmModel.description,
                            cls: ImLLMModel.self) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case let .success(models):
                    guard let model = models.first(where: { $0.isDefault == true }) ?? models.first,
                          !(model.apiKey ?? "").isEmpty,
                          !(model.modelIdentifier ?? "").isEmpty else {
                        self.showAIError("请先在设置中配置有效 AI 模型。")
                        return
                    }
                    let prompt = "只评价以下学习者的理解，不重述题目。依据第一性原理检验因果与假设，使用奥卡姆剃刀指出不必要的复杂度；简短指出一个准确点、一个不足和一个可执行的改进建议。\n\n题目：" +
                        entry.question + "\n回答：" + entry.userAnswer
                    ImNetWorkRequest.shared.requestPollingChat(
                        messages: [["role":"user", "content": prompt]],
                        llm: model,
                        systemPrompt: "你是严谨的学习反馈教练。不得杜撰用户未提供的事实。"
                    ) { outcome in
                        DispatchQueue.main.async {
                            switch outcome {
                            case let .success(response):
                                do {
                                    try ImpressV3LearningJournal.attachFeedback(
                                        response.content, to: entry.id)
                                    self.reloadLearningHistory()
                                    detail?.navigationController?.popViewController(animated: true)
                                } catch { self.showAIError(error.localizedDescription) }
                            case let .failure(error):
                                self.showAIError(error.localizedDescription)
                            }
                        }
                    }
                case let .failure(error):
                    self.showAIError(error.localizedDescription)
                }
            }
        }
    }

    private func showAIError(_ message: String) {
        let alert = UIAlertController(title: "AI 评价未完成", message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}


// MARK: - R03 secondary native settings IA (never adds bottom tabs)

@MainActor
final class ImpressV3SettingsHubViewController: UITableViewController {
    private enum Destination {
        case nativeChat, deepSeek, models, prompts, reminders, advanced
    }
    private struct Option {
        let title: String
        let subtitle: String
        let symbol: String
        let destination: Destination
    }

    private let groupTitles = ["人工智能", "复习提醒", "应用"]
    private let groups: [[Option]] = [
        [
            Option(title: "AI 问答", subtitle: "使用已配置的 API 模型进行原生对话",
                   symbol: "bubble.left.and.bubble.right", destination: .nativeChat),
            Option(title: "DeepSeek 网页", subtitle: "打开官方网页，登录及发送由用户控制",
                   symbol: "globe", destination: .deepSeek),
            Option(title: "模型配置", subtitle: "管理模型、服务地址和 API 密钥",
                   symbol: "cpu", destination: .models),
            Option(title: "提示词", subtitle: "编辑自己的学习与评价指导",
                   symbol: "text.quote", destination: .prompts)
        ],
        [
            Option(title: "提醒通知", subtitle: "关闭、智能到期或每日习惯提醒",
                   symbol: "bell", destination: .reminders)
        ],
        [
            Option(title: "高级设置", subtitle: "其他工具和兼容性选项",
                   symbol: "slider.horizontal.3", destination: .advanced)
        ]
    ]

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        // Settings is a pushed secondary screen, not a second app root.
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 68
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        groups.count
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        groups[section].count
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        groupTitles[section]
    }

    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        section == 0 ? "原生 AI 问答与 DeepSeek 网页是两个独立的功能；不会自动上传私人笔记。" : nil
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = groups[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = option.title
        content.secondaryText = option.subtitle
        content.image = UIImage(systemName: option.symbol)
        content.imageProperties.tintColor = .systemBlue
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = groups[indexPath.section][indexPath.row]
        switch option.destination {
        case .nativeChat:
            let chat = ImPollingChatViewController()
            chat.title = "AI 问答"
            navigationController?.pushViewController(chat, animated: true)
        case .deepSeek:
            navigationController?.pushViewController(
                ImWebViewController.forDirectBrowse(), animated: true)
        case .models:
            present(ImNavigationViewController(
                rootViewController: ImLLMConfigViewController()), animated: true)
        case .prompts:
            navigationController?.pushViewController(
                ImSystemPromptViewController(viewModel: ImSettingsViewModel()),
                animated: true)
        case .reminders:
            navigationController?.pushViewController(
                ImpressV3ReminderSettingsController(), animated: true)
        case .advanced:
            navigationController?.pushViewController(
                ImSettingsViewController(), animated: true)
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
        tableView.backgroundColor = .systemGroupedBackground
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
