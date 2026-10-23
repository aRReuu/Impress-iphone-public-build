import XCTest
import UIKit
@testable import aReuImpress_iPhone

@MainActor
final class ImpressChatPOCLocalAttachmentTests: XCTestCase {
    func testThreeFrozenSystemPickerChoicesAndBoundedLocalPreview() throws {
        let owner = UIViewController()
        let coordinator = ImpressChatPOCLocalAttachments(presenting: owner)
        let menu = coordinator.pickerMenu()
        let labels = menu.children.compactMap { ($0 as? UIAction)?.title }
        XCTAssertEqual(labels, ["相册", "文件", "拍照"])
        var changes = 0
        coordinator.onChange = { _ in changes += 1 }
        for i in 0..<7 {
            coordinator.addSyntheticPreviewForTest("synthetic \(i)")
        }
        XCTAssertEqual(coordinator.items.count, 5)
        XCTAssertEqual(changes, 5)
        XCTAssertTrue(coordinator.items.allSatisfy { $0.approximateBytes == 100 })
        let first = try XCTUnwrap(coordinator.items.first)
        coordinator.remove(id: first.id)
        XCTAssertEqual(coordinator.items.count, 4)
        XCTAssertEqual(changes, 6)
    }

    func testComposerExposesSystemPickerButNoAutomaticTransmission() throws {
        let vc = ImpressChatPOCViewController()
        vc.loadViewIfNeeded()
        let buttons = findSubviews(in: vc.view, type: UIButton.self)
        let add = try XCTUnwrap(buttons.first {
            $0.accessibilityIdentifier == "impress.chat.poc.add"
        })
        XCTAssertEqual(add.menu?.children.count, 3)
        XCTAssertTrue(add.showsMenuAsPrimaryAction)
        let status = try XCTUnwrap(buttons.first {
            $0.accessibilityIdentifier == "impress.chat.poc.local-preview"
        })
        XCTAssertTrue(status.isHidden)
    }

    private func findSubviews<T: UIView>(in root: UIView, type: T.Type) -> [T] {
        root.subviews.flatMap { view in
            ((view as? T).map { [$0] } ?? []) + findSubviews(in: view, type: type)
        }
    }
}
