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
        let options = answer.subviews.compactMap { $0 as? UIStackView }
            .flatMap { $0.arrangedSubviews.compactMap { $0 as? UIButton } }
        XCTAssertEqual(options.count, 2)
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
