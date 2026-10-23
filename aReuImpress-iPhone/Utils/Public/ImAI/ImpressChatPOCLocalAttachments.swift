#if DEBUG
import Foundation
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

/// Disposable, local-only POC material. The typed payload is intentionally
/// not Codable and contains neither Vault authority nor model upload metadata.
@MainActor
struct ImpressChatPOCLocalPreview {
    enum Origin: String { case photo = "相册", file = "文件", camera = "拍照" }
    let id: UUID
    let title: String
    let source: Origin
    let approximateBytes: Int
    let thumbnail: UIImage?
}

/// Explicit, bounded UIKit system pickers. These items never enter SSE,
/// WCDB, provider requests or Vault writes. UI must confirm a future upload.
@MainActor
final class ImpressChatPOCLocalAttachments: NSObject,
    PHPickerViewControllerDelegate, UIDocumentPickerDelegate,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private weak var presenting: UIViewController?
    private(set) var items: [ImpressChatPOCLocalPreview] = []
    var onChange: (([ImpressChatPOCLocalPreview]) -> Void)?

    private let maxItems = 5
    private let maxItemBytes = 12 * 1_024 * 1_024

    init(presenting: UIViewController) {
        self.presenting = presenting
    }

    func pickerMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "相册", image: UIImage(systemName: "photo.on.rectangle")) {
                [weak self] _ in self?.openPhotos()
            },
            UIAction(title: "文件", image: UIImage(systemName: "folder")) {
                [weak self] _ in self?.openFiles()
            },
            UIAction(title: "拍照", image: UIImage(systemName: "camera")) {
                [weak self] _ in self?.openCamera()
            }
        ])
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        onChange?(items)
    }

    /// Deterministic unit-fixture path: never picks a device resource.
    func addSyntheticPreviewForTest(_ name: String) {
        insert(ImpressChatPOCLocalPreview(
            id: UUID(), title: name, source: .file, approximateBytes: 100,
            thumbnail: nil))
    }

    private func insert(_ item: ImpressChatPOCLocalPreview) {
        guard items.count < maxItems, item.approximateBytes <= maxItemBytes,
              !item.title.isEmpty else { return }
        items.append(item)
        onChange?(items)
    }

    private func capacityAvailable() -> Bool {
        if items.count < maxItems { return true }
        showNotice("一次最多预览 5 项材料；请先移除一项。")
        return false
    }

    private func openPhotos() {
        guard capacityAvailable(), let presenting else { return }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = maxItems - items.count
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenting.present(picker, animated: true)
    }

    private func openFiles() {
        guard capacityAvailable(), let presenting else { return }
        // asCopy keeps the original Files/iCloud Provider item unchanged.
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        presenting.present(picker, animated: true)
    }

    private func openCamera() {
        guard capacityAvailable(), let presenting else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showNotice("此设备没有可使用的相机。")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = self
        presenting.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController,
                didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results.prefix(maxItems - items.count) {
            let provider = result.itemProvider
            guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            else { continue }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
                [weak self] bytes, _ in
                Task { @MainActor [weak self] in
                    guard let self, let bytes, bytes.count <= self.maxItemBytes,
                          let image = Self.boundedThumbnail(from: bytes) else {
                        self?.showNotice("图片超过安全大小或无法预览。")
                        return
                    }
                    self.insert(ImpressChatPOCLocalPreview(
                        id: UUID(), title: provider.suggestedName ?? "本地图片",
                        source: .photo, approximateBytes: bytes.count,
                        thumbnail: image))
                }
            }
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        for url in urls.prefix(maxItems - items.count) {
            guard url.isFileURL else { continue }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  let info = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = info[.size] as? NSNumber,
                  size.intValue <= maxItemBytes else {
                showNotice("文件超过安全大小或不可读取。")
                continue
            }
            insert(ImpressChatPOCLocalPreview(
                id: UUID(), title: String(url.lastPathComponent.prefix(100)),
                source: .file, approximateBytes: size.intValue,
                thumbnail: nil))
        }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info:
                               [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let bytes = image.jpegData(compressionQuality: 0.72),
              bytes.count <= maxItemBytes,
              let thumb = Self.boundedThumbnail(from: bytes) else {
            showNotice("照片无法安全预览。")
            return
        }
        insert(ImpressChatPOCLocalPreview(
            id: UUID(), title: "本地拍摄照片", source: .camera,
            approximateBytes: bytes.count, thumbnail: thumb))
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    private static func boundedThumbnail(from bytes: Data) -> UIImage? {
        guard bytes.count <= 12 * 1_024 * 1_024,
              let image = CGImageSourceCreateWithData(bytes as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(image, 0, nil)
                  as NSDictionary?,
              let width = metadata[kCGImagePropertyPixelWidth] as? Int,
              let height = metadata[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              width <= 8_192, height <= 8_192,
              width * height <= 20_000_000 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(image, 0,
                                                               options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: thumb)
    }

    private func showNotice(_ detail: String) {
        guard let presenting, presenting.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "本地材料预览", message: detail,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        presenting.present(alert, animated: true)
    }
}
#endif
