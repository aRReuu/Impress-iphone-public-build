import XCTest
import UIKit
import ImpressReviewCore
@testable import aReuImpress_iPhone

/// A real UIKit/SwipeCardStack integration test, not a mocked gesture stack.
/// Uses the V3 database in an isolated temporary location on iOS Simulator.
@MainActor
final class ImpressV3SwipeIntegrationTests: XCTestCase {
    private func makeRepository() throws -> ReviewWCDBRepository {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("V3Swipe-" + UUID().uuidString, isDirectory: true)
            .appendingPathComponent("cards.sqlite").path
        return try ReviewWCDBRepository(databasePath: path,
                                        calculator: FSRS6ReviewCalculator())
    }

    private func eventually(timeout: TimeInterval = 4.0,
                            _ predicate: @escaping @MainActor () -> Bool) async throws -> Bool {
        let count = Int(timeout / 0.08)
        for _ in 0..<count {
            if predicate() { return true }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        return predicate()
    }

    func testActualTinderSwipeSavesOneFSRSEventOnlyAfterRevealingAnswer() async throws {
        let repository = try makeRepository()
        let cardID = UUID()
        let time = Date()
        let seed = try FSRS6ReviewCalculator().newCardSnapshot(id: cardID, now: time)
        try await repository.insertNewCard(
            WCDBV3CardInput(cardID: cardID,
                            question: "What is active recall?",
                            answerText: "Retrieving knowledge without rereading."),
            initial: seed, now: time)

        let controller = ImpressV3ReviewViewController(repository: repository)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()

        guard let stack = controller.view.subviews.compactMap({ $0 as? SwipeCardStack }).first else {
            XCTFail("V3 should render the original SwipeCardStack")
            return
        }
        let prepared = try await eventually {
            stack.topCard?.content is ImMemoryCardView
        }
        XCTAssertTrue(prepared)
        XCTAssertEqual(stack.topCardIndex, 0)
        XCTAssertFalse(stack.topCard?.panGestureRecognizer.isEnabled ?? true)
        let before = try await repository.reviewHistory(for: cardID)
        XCTAssertTrue(before.isEmpty)

        guard let content = stack.topCard?.content as? ImMemoryCardView else {
            XCTFail("Expected the existing text/image card content view")
            return
        }
        content.revealAnswerIfNeeded()
        let enabled = try await eventually {
            stack.topCard?.panGestureRecognizer.isEnabled == true
        }
        XCTAssertTrue(enabled, "The answer must be revealed before rating")

        // Exercise the real card animator, delegate index, FSRS calculator and
        // WCDB transaction. A successful swipe must produce exactly one event.
        stack.swipe(.right, animated: true)
        let committed = try await eventually(timeout: 7) {
            stack.numberOfRemainingCards() == 0
        }
        XCTAssertTrue(committed)
        let eventsAvailable = try await eventually(timeout: 7) {
            let labels = controller.view.subviews.compactMap { $0 as? UILabel }
            return labels.contains { $0.text?.contains("本轮完成") == true }
        }
        XCTAssertTrue(eventsAvailable, "The last swipe must await animation and commit")
        let events = try await repository.reviewHistory(for: cardID)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.rating, .easy)
        XCTAssertEqual(events.first?.before.revision, 0)
        XCTAssertEqual(events.first?.after.revision, 1)
    }

    func testMultipleChoiceAnswerRequiresExplicitGradeSwipe() async throws {
        let repository = try makeRepository()
        let id = UUID()
        let now = Date()
        try await repository.insertNewCard(
            WCDBV3CardInput(cardID: id, question: "Choose the true statement",
                            choices: "A\nB", correctIndices: "0", cardType: 2),
            initial: FSRS6ReviewCalculator().newCardSnapshot(id: id, now: now),
            now: now)

        let controller = ImpressV3ReviewViewController(repository: repository)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        guard let stack = controller.view.subviews.compactMap({ $0 as? SwipeCardStack }).first else {
            XCTFail("Expected original Tinder stack")
            return
        }
        let cardReady = try await eventually { stack.topCard?.content is ImMultipleChoiceCardView }
        XCTAssertTrue(cardReady)
        XCTAssertFalse(stack.topCard?.panGestureRecognizer.isEnabled ?? true)
        guard let answer = stack.topCard?.content as? ImMultipleChoiceCardView else {
            XCTFail("Multiple choice card missing")
            return
        }
        // R04.2-D2: native options live inside a vertically scrollable
        // card container; no longer look only at immediate subviews.
        func buttons(in root: UIView) -> [UIButton] {
            let own = (root as? UIButton).map { [$0] } ?? []
            return own + root.subviews.flatMap(buttons(in:))
        }
        let options = buttons(in: answer)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(answer.subviews.compactMap { $0 as? UIScrollView }.count, 1)
        XCTAssertTrue(options.allSatisfy { $0.buttonType == .system })
        answer.showAnswer()
        let revealed = try await eventually {
            stack.topCard?.panGestureRecognizer.isEnabled == true
        }
        XCTAssertTrue(revealed)
        let events = try await repository.reviewHistory(for: id)
        XCTAssertEqual(events.count, 0, "Answering a multiple-choice question is not an FSRS grade")
    }
    func testAllFourDirectionsPersistCorrectFSRSRating() async throws {
        let cases: [(SwipeDirection, ReviewRating)] = [
            (.down, .again), (.left, .hard), (.up, .good), (.right, .easy)
        ]
        for (direction, rating) in cases {
            let repository = try makeRepository()
            let id = UUID()
            let now = Date()
            try await repository.insertNewCard(
                WCDBV3CardInput(cardID: id, question: "Q", answerText: "A"),
                initial: try FSRS6ReviewCalculator().newCardSnapshot(id: id, now: now),
                now: now)
            let controller = ImpressV3ReviewViewController(repository: repository)
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = UINavigationController(rootViewController: controller)
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            controller.loadViewIfNeeded()
            guard let stack = controller.view.subviews.compactMap({ $0 as? SwipeCardStack }).first else {
                XCTFail("Missing the original Tinder SwipeCardStack")
                return
            }
            let ready = try await eventually { stack.topCard?.content is ImMemoryCardView }
            XCTAssertTrue(ready)
            (stack.topCard?.content as? ImMemoryCardView)?.revealAnswerIfNeeded()
            let enabled = try await eventually {
                stack.topCard?.panGestureRecognizer.isEnabled == true
            }
            XCTAssertTrue(enabled)
            stack.swipe(direction, animated: true)
            let finished = try await eventually(timeout: 7) {
                controller.view.subviews.compactMap { $0 as? UILabel }
                    .contains(where: { $0.text == "本轮完成" })
            }
            XCTAssertTrue(finished, "Direction \(direction) must wait for a durable grade")
            let events = try await repository.reviewHistory(for: id)
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(events.first?.rating, rating)
        }
    }

    func testRapidDuplicateSwipeCannotCreateSecondWCDBEvent() async throws {
        let repo = try makeRepository()
        let id = UUID()
        let now = Date()
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: id, question: "Double tap?", answerText: "Once"),
            initial: try FSRS6ReviewCalculator().newCardSnapshot(id: id, now: now), now: now)
        let controller = ImpressV3ReviewViewController(repository: repo)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        guard let stack = controller.view.subviews.compactMap({ $0 as? SwipeCardStack }).first else {
            XCTFail("Missing SwipeCardStack")
            return
        }
        let ready = try await eventually { stack.topCard?.content is ImMemoryCardView }
        XCTAssertTrue(ready)
        (stack.topCard?.content as? ImMemoryCardView)?.revealAnswerIfNeeded()
        let enabled = try await eventually {
            stack.topCard?.panGestureRecognizer.isEnabled == true
        }
        XCTAssertTrue(enabled)
        stack.swipe(.left, animated: true)
        stack.swipe(.right, animated: true)
        let finished = try await eventually(timeout: 7) {
            controller.view.subviews.compactMap { $0 as? UILabel }
                .contains(where: { $0.text == "本轮完成" })
        }
        XCTAssertTrue(finished)
        let events = try await repo.reviewHistory(for: id)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.rating, .hard)
    }

    func testInterruptedTwoCardSwipeStillAdvancesOnlyAfterSingleCommit() async throws {
        let repo = try makeRepository()
        let firstID = UUID()
        let secondID = UUID()
        let now = Date()
        let calc = FSRS6ReviewCalculator()
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: firstID, question: "First", answerText: "A"),
            initial: try calc.newCardSnapshot(id: firstID, now: now.addingTimeInterval(-2)),
            now: now.addingTimeInterval(-2))
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: secondID, question: "Second", answerText: "B"),
            initial: try calc.newCardSnapshot(id: secondID, now: now.addingTimeInterval(-1)),
            now: now.addingTimeInterval(-1))
        let controller = ImpressV3ReviewViewController(repository: repo)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        guard let stack = controller.view.subviews.compactMap({ $0 as? SwipeCardStack }).first else {
            XCTFail("Missing SwipeCardStack")
            return
        }
        let firstReady = try await eventually { stack.topCard?.content is ImMemoryCardView }
        XCTAssertTrue(firstReady)
        XCTAssertEqual(stack.topCardIndex, 0)
        (stack.topCard?.content as? ImMemoryCardView)?.revealAnswerIfNeeded()
        let gestureEnabled = try await eventually {
            stack.topCard?.panGestureRecognizer.isEnabled == true
        }
        XCTAssertTrue(gestureEnabled)
        guard let retiringCard = stack.topCard else {
            XCTFail("First card not found")
            return
        }
        stack.swipe(.up, animated: true)
        // Simulates UIKit animation cancellation during an interruption.
        retiringCard.removeAllAnimations()
        stack.backgroundCards.forEach { $0.removeAllAnimations() }

        let resumed = try await eventually(timeout: 8) {
            stack.topCardIndex == 1 && stack.isUserInteractionEnabled &&
                stack.topCard?.content is ImMemoryCardView
        }
        XCTAssertTrue(resumed, "Animation interruption must not strand persisted review")
        let firstEvents = try await repo.reviewHistory(for: firstID)
        let secondEvents = try await repo.reviewHistory(for: secondID)
        XCTAssertEqual(firstEvents.count, 1)
        XCTAssertEqual(firstEvents.first?.rating, .good)
        XCTAssertTrue(secondEvents.isEmpty)
    }

    func testFailedWCDBCommitRestoresCardAndAllowsExactlyOneRetry() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("V3SwipeFailure-" + UUID().uuidString, isDirectory: true)
            .appendingPathComponent("cards.sqlite").path
        let repository = try ReviewWCDBRepository(
            databasePath: path, calculator: OneShotReviewCalculator())
        let id = UUID()
        let now = Date()
        try await repository.insertNewCard(
            WCDBV3CardInput(cardID: id, question: "Retry?", answerText: "Yes."),
            initial: try FSRS6ReviewCalculator().newCardSnapshot(id: id, now: now),
            now: now)

        let controller = ImpressV3ReviewViewController(repository: repository)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        guard let stack = controller.view.subviews.compactMap({ $0 as? SwipeCardStack }).first else {
            XCTFail("Expected the Tinder card stack")
            return
        }
        let ready = try await eventually { stack.topCard?.content is ImMemoryCardView }
        XCTAssertTrue(ready)
        (stack.topCard?.content as? ImMemoryCardView)?.revealAnswerIfNeeded()
        let enabled = try await eventually { stack.topCard?.panGestureRecognizer.isEnabled == true }
        XCTAssertTrue(enabled)
        stack.swipe(.left, animated: true)

        let recovered = try await eventually(timeout: 8) {
            stack.topCardIndex == 0 &&
                stack.topCard?.panGestureRecognizer.isEnabled == true &&
                stack.isUserInteractionEnabled
        }
        XCTAssertTrue(recovered, "Failed ratings must restore the SAME interactable card")
        let before = try await repository.reviewHistory(for: id)
        XCTAssertTrue(before.isEmpty)

        stack.swipe(.up, animated: true)
        let completed = try await eventually(timeout: 7) {
            controller.view.subviews.compactMap { $0 as? UILabel }
                .contains(where: { $0.text == "本轮完成" })
        }
        XCTAssertTrue(completed)
        let events = try await repository.reviewHistory(for: id)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.rating, .good)
    }

}


private enum OneShotReviewFailure: Swift.Error { case injected }

private final class OneShotReviewCalculator: WCDBReviewCalculating, @unchecked Sendable {
    private let lock = NSLock()
    private var failNext = true

    func next(before: ReviewScheduleSnapshot, status: ReviewCardStatus,
              submission: ReviewSubmission) throws -> WCDBCalculatedReview {
        lock.lock()
        let shouldFail = failNext
        failNext = false
        lock.unlock()
        if shouldFail { throw OneShotReviewFailure.injected }
        return try FSRS6ReviewCalculator().next(
            before: before, status: status, submission: submission)
    }
}


// R04 native web handoff is pure until the user copies/pastes in DeepSeek.
// This must never create a second FSRS event or start a native chat.
final class ImpressV3DeepSeekHandoffTests: XCTestCase {
    func testDeepSeekPayloadUsesCurrentQuestionAndFirstPrinciplesByDefault() {
        let payload = ImpressV3DeepSeekHandoff.makePayload(
            question: "检验假设", answer: "观察因果", userPrompt: nil)
        XCTAssertTrue(payload.contains("第一性原理"))
        XCTAssertTrue(payload.contains("检验假设"))
        XCTAssertTrue(payload.contains("观察因果"))
    }

    func testDeepSeekPayloadRespectsSavedUserPromptWithoutAutoSending() {
        let payload = ImpressV3DeepSeekHandoff.makePayload(
            question: "问题", answer: nil, userPrompt: "自定义学习方式")
        XCTAssertTrue(payload.contains("自定义学习方式"))
        XCTAssertTrue(payload.contains("没有可用的文字答案"))
    }
}


// R04.2-D current navigation contract: Settings is a primary tab,
// with prompt-library / reminder choices, not legacy chat and model rows.
@MainActor
final class ImpressR041NativeNavigationTests: XCTestCase {
    func testSettingsHasTwoNativeGroupedSectionsWithNoOldModelEntries() {
        let settings = ImpressV3SettingsHubViewController()
        settings.loadViewIfNeeded()
        XCTAssertEqual(settings.numberOfSections(in: settings.tableView), 2)
        XCTAssertEqual(settings.tableView(settings.tableView,
                          numberOfRowsInSection: 0), 1)
        XCTAssertEqual(settings.tableView(settings.tableView,
                          numberOfRowsInSection: 1), 1)
        XCTAssertEqual(settings.navigationItem.largeTitleDisplayMode, .always)
        let cell = settings.tableView(settings.tableView,
                          cellForRowAt: IndexPath(row: 0, section: 0))
        let content = cell.contentConfiguration as? UIListContentConfiguration
        XCTAssertEqual(content?.text, "提示词")
    }

    func testDirectWebBrowserDoesNotAutoSendPrivateQuestions() {
        let browser = ImWebViewController.forDirectBrowse()
        browser.loadViewIfNeeded()
        XCTAssertEqual(browser.title, "网页聊天")
        XCTAssertTrue(browser.navigationItem.leftBarButtonItems?.isEmpty ?? true)
        let actions = browser.navigationItem.rightBarButtonItems ?? []
        XCTAssertFalse(actions.contains { $0.title == "复制问题" })
        XCTAssertTrue(actions.contains { $0.accessibilityLabel == "从提示词库复制" })
    }
}

// CI alone cannot sign off the iPhone appearance. These tests guard the
// actual semantic roles, tab coloring and native selected-control state.
@MainActor
final class ImpressR042AppearanceTests: XCTestCase {
    func testGroupedCanvasAndElevatedSurfacesUseOneAuthority() {
        XCTAssertEqual(ImpressV3Appearance.page, UIColor.systemGroupedBackground)
        XCTAssertEqual(ImpressV3Appearance.surface,
                       UIColor.secondarySystemGroupedBackground)
        XCTAssertEqual(ImpressV3Appearance.accent, funBtnColor)
        let bar = UITabBar()
        ImpressV3Appearance.styleTabBar(bar)
        XCTAssertEqual(bar.tintColor, ImpressV3Appearance.accent)
        XCTAssertEqual(bar.unselectedItemTintColor, ImpressV3Appearance.secondaryText)
        let navigation = UINavigationBar()
        ImpressV3Appearance.styleNavigationBar(navigation)
        XCTAssertEqual(navigation.tintColor, ImpressV3Appearance.accent)
    }

    func testNativeThreeTypeSelectorHasHighContrastActiveSegment() throws {
        let composer = ImpressV3CardComposerViewController()
        composer.loadViewIfNeeded()
        func findSegments(_ view: UIView) -> [UISegmentedControl] {
            let own = (view as? UISegmentedControl).map { [$0] } ?? []
            return own + view.subviews.flatMap(findSegments)
        }
        let selectors = findSegments(composer.view)
        let types = try XCTUnwrap(selectors.first(where: { $0.numberOfSegments == 3 }))
        let answerMode = try XCTUnwrap(selectors.first(where: { $0.numberOfSegments == 2 }))
        XCTAssertEqual(types.selectedSegmentTintColor, ImpressV3Appearance.accent)
        XCTAssertEqual(types.backgroundColor, ImpressV3Appearance.segmentTrack)
        XCTAssertEqual(types.accessibilityLabel, "卡片类型")
        XCTAssertEqual(types.selectedSegmentIndex, 0)
        XCTAssertEqual(answerMode.selectedSegmentTintColor,
                       ImpressV3Appearance.secondarySegmentSelection)
        XCTAssertEqual(answerMode.accessibilityLabel, "单选或多选")
        let attrs = types.titleTextAttributes(for: .selected)
        XCTAssertNotNil(attrs?[.font] as? UIFont)
        XCTAssertEqual(attrs?[.foregroundColor] as? UIColor,
                       ImpressV3Appearance.primaryButtonText)
    }
    func testCentralButtonTapTargetsAndQuietSecondaryFeedback() {
        guard #available(iOS 15.0, *) else { return }
        let main = UIButton(type: .system)
        ImpressV3NativeButtonAppearance.primary(main, title: "查看答案")
        XCTAssertEqual(main.configuration?.baseBackgroundColor,
                       ImpressV3Appearance.accent)
        XCTAssertTrue(main.constraints.contains {
            $0.firstAttribute == .height &&
            $0.relation == .greaterThanOrEqual &&
            $0.constant >= ImpressV3Appearance.Metrics.primaryActionHeight
        })

        let secondary = UIButton(type: .system)
        ImpressV3NativeButtonAppearance.quiet(
            secondary, title: "选择图片", symbol: "photo")
        XCTAssertEqual(secondary.configuration?.baseBackgroundColor,
                       ImpressV3Appearance.quietControlSurface)
        XCTAssertTrue(secondary.constraints.contains {
            $0.firstAttribute == .height &&
            $0.relation == .greaterThanOrEqual &&
            $0.constant >= ImpressV3Appearance.Metrics.controlHeight
        })
    }

    func testSegmentsHaveEqualItemsAndResponsiveMaximumWidth() {
        let picker = UISegmentedControl(items: ["问答", "选择题", "图片"])
        ImpressV3Appearance.styleSegmentedControl(picker, prominent: true)
        let row = ImpressV3Appearance.segmentedRow(picker)
        row.frame = CGRect(x: 0, y: 0, width: 350, height: 50)
        row.setNeedsLayout()
        row.layoutIfNeeded()
        XCTAssertFalse(picker.apportionsSegmentWidthsByContent)
        XCTAssertEqual(picker.numberOfSegments, 3)
        XCTAssertGreaterThan(picker.bounds.width, 300)
        XCTAssertTrue(picker.constraints.contains {
            $0.firstAttribute == .height &&
            $0.relation == .greaterThanOrEqual &&
            $0.constant >= ImpressV3Appearance.Metrics.segmentHeight
        })
        row.frame.size.width = 900
        row.setNeedsLayout()
        row.layoutIfNeeded()
        XCTAssertLessThanOrEqual(
            picker.bounds.width, ImpressV3Appearance.Metrics.maximumSegmentWidth + 1)
    }

    func testBatchImportFormatSegmentsAreShortAndAccessible() throws {
        let importer = ImpressV3BatchImportViewController()
        importer.loadViewIfNeeded()
        func segments(in root: UIView) -> [UISegmentedControl] {
            let own = (root as? UISegmentedControl).map { [$0] } ?? []
            return own + root.subviews.flatMap(segments(in:))
        }
        let selector = try XCTUnwrap(segments(in: importer.view).first)
        XCTAssertEqual(selector.numberOfSegments, 4)
        XCTAssertEqual(selector.titleForSegment(at: 3), "MD")
        XCTAssertEqual(selector.accessibilityLabel, "导入格式")
        XCTAssertEqual(selector.selectedSegmentTintColor,
                       ImpressV3Appearance.secondarySegmentSelection)
    }

    func testTwelveAnswerChoicesRemainScrollableWithoutDuplicateRating() {
        guard #available(iOS 15.0, *) else { return }
        var model = ImCardModel()
        model.question = "从 12 个选项中选择正确项"
        model.cardType = CardType.multipleChoice.rawValue
        model.choices = (1...12).map { "选项 \($0)" }.joined(separator: "\n")
        model.correctAnswerIndices = "0,4"
        let view = ImMultipleChoiceCardView(
            model: model, usesNativeOptionButtons: true)
        view.frame = CGRect(x: 0, y: 0, width: 350, height: 420)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        func descendants<T: UIView>(_ root: UIView, _ type: T.Type) -> [T] {
            let own = (root as? T).map { [$0] } ?? []
            return own + root.subviews.flatMap { descendants($0, type) }
        }
        let options = descendants(view, UIButton.self)
        XCTAssertEqual(options.count, 12)
        XCTAssertEqual(descendants(view, UIScrollView.self).count, 1)
        XCTAssertTrue(options.allSatisfy { button in
            button.constraints.contains {
                $0.firstAttribute == .height &&
                $0.relation == .greaterThanOrEqual &&
                $0.constant >= ImpressV3Appearance.Metrics.answerOptionHeight
            }
        })
        XCTAssertTrue(options.allSatisfy {
            $0.configuration?.background.backgroundColor == ImpressV3Appearance.optionSurface
        })
        XCTAssertFalse(view.answerIsRevealed)
        view.showAnswer()
        XCTAssertTrue(view.answerIsRevealed)
        XCTAssertFalse(options[0].isUserInteractionEnabled)
        XCTAssertTrue(options[0].isEnabled) // no dimmed correct-answer text
        XCTAssertEqual(options[0].configuration?.background.backgroundColor,
                       ImpressV3Appearance.correctOptionSurface)
        XCTAssertEqual(options[1].configuration?.background.backgroundColor,
                       ImpressV3Appearance.optionSurface)
    }

}

// R04.2: native creation must be separate from legacy generic ImSubmit,
// must preserve uncommitted content when switching card types, and must
// serialize choice answers without changing WCDB schema or FSRS semantics.
@MainActor
final class ImpressR042CardComposerTests: XCTestCase {
    func testChoiceSerializesWithoutSpecialSyntax() throws {
        var draft = ImpressV3CardDraft()
        draft.kind = .multipleChoice
        draft.question = "唐朝开国皇帝是谁？"
        draft.choices = [
            .init(text: "李世民", isCorrect: false),
            .init(text: "李渊", isCorrect: true),
            .init(text: "李白", isCorrect: false)
        ]
        let input = try draft.validatedInput()
        XCTAssertEqual(input.cardType, CardType.multipleChoice.rawValue)
        XCTAssertEqual(input.question, "唐朝开国皇帝是谁？")
        XCTAssertEqual(input.choices, "李世民\n李渊\n李白")
        XCTAssertEqual(input.correctIndices, "1")
        XCTAssertEqual(input.answerText, "李渊")
    }

    func testMultipleAnswerSerializesSortedIndicesAndSourcePath() throws {
        var draft = ImpressV3CardDraft()
        draft.kind = .multipleChoice
        draft.question = "选择正确选项"
        draft.allowsMultipleCorrect = true
        draft.sourceNotePath = "知识/物理/问题.md"
        draft.choices = [
            .init(text: "C", isCorrect: true),
            .init(text: "A", isCorrect: false),
            .init(text: "B", isCorrect: true)
        ]
        let card = try draft.validatedInput()
        XCTAssertEqual(card.correctIndices, "0,2")
        XCTAssertEqual(card.sourceNotePath, "知识/物理/问题.md")
    }

    func testInvalidChoiceRefusesSaveAndDoesNotGuessCorrectAnswer() {
        var draft = ImpressV3CardDraft()
        draft.kind = .multipleChoice
        draft.question = "Question"
        draft.choices = [.init(text: "A"), .init(text: "B")]
        XCTAssertThrowsError(try draft.validatedInput())
        draft.choices[0].isCorrect = true
        draft.choices[1].text = "A"
        XCTAssertThrowsError(try draft.validatedInput())
    }

    func testSwitchingVisibleEditorPreservesQuestionAndAnswer() throws {
        let composer = ImpressV3CardComposerViewController()
        composer.loadViewIfNeeded()
        func descendants<T: UIView>(_ root: UIView, matching type: T.Type) -> [T] {
            (root as? T).map { [$0] } ?? root.subviews.flatMap { descendants($0, matching: type) }
        }
        let fields = descendants(composer.view, matching: UITextView.self)
        XCTAssertEqual(fields.count, 2)
        guard fields.count == 2 else { return }
        fields[0].text = "问题草稿"
        fields[1].text = "答案草稿"
        let switchers = descendants(composer.view, matching: UISegmentedControl.self)
        guard let picker = switchers.first(where: { $0.numberOfSegments == 3 }) else {
            return XCTFail("Missing native card type switcher")
        }
        picker.selectedSegmentIndex = 1
        picker.sendActions(for: .valueChanged)
        picker.selectedSegmentIndex = 2
        picker.sendActions(for: .valueChanged)
        picker.selectedSegmentIndex = 0
        picker.sendActions(for: .valueChanged)
        XCTAssertEqual(fields[0].text, "问题草稿")
        XCTAssertEqual(fields[1].text, "答案草稿")
    }
}
