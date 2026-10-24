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
        XCTAssertNotNil(Bundle.main.object(
            forInfoDictionaryKey: "NSCameraUsageDescription"),
            "The camera picker must never launch without a declared usage string")
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
        let stt = try XCTUnwrap(buttons.first {
            $0.accessibilityIdentifier == "impress.chat.poc.apple-stt"
        })
        XCTAssertEqual(stt.accessibilityLabel, "Apple 语音转文字")
        XCTAssertEqual(stt.constraints.first(where: {
            $0.firstAttribute == .width && $0.constant == 44
        })?.constant, 44)
        let status = try XCTUnwrap(buttons.first {
            $0.accessibilityIdentifier == "impress.chat.poc.local-preview"
        })
        XCTAssertTrue(status.isHidden)
        vc.addSyntheticLocalMaterialForTest("QA Thumbnail")
        XCTAssertFalse(status.isHidden)
        let previews = findSubviews(in: vc.view, type: UIButton.self)
            .filter { $0.accessibilityIdentifier?.hasPrefix("impress.chat.poc.preview.") == true }
        XCTAssertEqual(previews.count, 1)
        XCTAssertTrue(previews[0].accessibilityLabel?.contains("未发送") == true)
        previews[0].sendActions(for: .touchUpInside)
        XCTAssertTrue(status.isHidden)
    }

    func testSyntheticApprovedImagesRemainTransientAndMixedFilesFailClosed() throws {
        let owner = UIViewController()
        let picker = ImpressChatPOCLocalAttachments(presenting: owner)
        picker.addSyntheticImageForTest("synthetic 1.jpg")
        picker.addSyntheticImageForTest("synthetic 2.jpg")
        let authorized = try XCTUnwrap(picker.imagePayloadsForExplicitSend())
        XCTAssertEqual(authorized.count, 2)
        XCTAssertTrue(authorized.allSatisfy {
            $0.jpeg.starts(with: [0xFF, 0xD8, 0xFF]) &&
                $0.jpeg.suffix(2).elementsEqual([0xFF, 0xD9]) &&
                $0.jpeg.count <= 400_000
        })
        picker.addSyntheticPreviewForTest("unverified.pdf")
        XCTAssertNil(picker.imagePayloadsForExplicitSend(),
            "Never silently omit a selected nonimage document from consent")
        picker.clear()
        XCTAssertTrue(picker.items.isEmpty)
        XCTAssertNil(picker.imagePayloadsForExplicitSend())
    }

    func testHistoricalUserImageApprovalIsMetadataOnlyAndBackwardCompatible() throws {
        let legacy = WCDBV3ChatMessage(role: .user, text: "Describe",
                                       status: .completed)
        let bytes = try JSONEncoder().encode(legacy)
        let old = try JSONDecoder().decode(WCDBV3ChatMessage.self, from: bytes)
        XCTAssertNil(old.approvedImages)
        let uploaded = WCDBV3ChatMessage(role: .user, text: "Describe",
            status: .completed, approvedImages: [
                WCDBV3ChatImageApproval(name: "sample.jpg", jpegBytes: 394)
            ])
        let json = try JSONEncoder().encode(uploaded)
        let decoded = try JSONDecoder().decode(WCDBV3ChatMessage.self, from: json)
        XCTAssertEqual(decoded.approvedImages?.first?.name, "sample.jpg")
        XCTAssertFalse(String(data: json, encoding: .utf8)?.contains("base64") ?? false,
            "WCDB image receipts may never archive the source's pixel bytes")
        let viewport = ImpressChatProductionTranscript(
            frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let root = UIViewController()
        let window = UIWindow(frame: viewport.bounds)
        window.rootViewController = root
        root.view.addSubview(viewport)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        viewport.update([decoded])
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            viewport.layoutIfNeeded()
            return self.findSubviews(in: viewport, type: UITextView.self)
                .contains { $0.text.contains("已批准图片") &&
                    $0.text.contains("sample.jpg") }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed,
            "The user must see an actual approval receipt in the native transcript")
    }

    private func findSubviews<T: UIView>(in root: UIView, type: T.Type) -> [T] {
        root.subviews.flatMap { view in
            ((view as? T).map { [$0] } ?? []) + findSubviews(in: view, type: type)
        }
    }
}
