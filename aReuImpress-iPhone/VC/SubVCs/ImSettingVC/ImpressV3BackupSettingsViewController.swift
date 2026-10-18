import UIKit
import UniformTypeIdentifiers

/// One native Settings destination. Manual export and restore always require
/// direct user actions; periodic local snapshots are deliberately silent.
@MainActor
final class ImpressV3BackupSettingsViewController: UITableViewController,
                                                    UIDocumentPickerDelegate {
    private enum PickerPurpose { case cloudFolder, restoreArchive }
    private var pendingPurpose: PickerPurpose?
    private var working = false

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("数据与备份")
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = V3L("数据与备份")
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        section == 1 && ImpressV3BackupCoordinator.cloudFolderSelected ? 2 : 1
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        V3L([V3L("本地自动备份"), V3L("iCloud Drive 副本"), V3L("恢复")][section])
    }

    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            let timestamp = UserDefaults.standard.object(
                forKey: ImpressV3BackupCoordinator.localDateKey) as? Date
            let last = timestamp.map { Self.dateFormatter.string(from: $0) } ?? V3L("尚无成功备份")
            return String(format: V3L("V3 数据变化后自动生成一致性快照。最近成功：%@。"), last) +
                V3L("不包含旧数据库、外部 Obsidian 原件、API Key 或 Vault 授权。") +
                V3L("当前 ZIP 未加密，获取文件者可读取其中学习数据。")
        case 1:
            let last = UserDefaults.standard.object(
                forKey: ImpressV3BackupCoordinator.cloudDateKey) as? Date
            let copied = last.map { Self.dateFormatter.string(from: $0) } ?? V3L("尚未写入")
            return String(format: V3L("首次手动授权文件夹，此后尝试静默复制。最近写入文件提供者：%@。"), copied) +
                V3L("副本为未加密 ZIP，请只授权个人可信目录。系统 iCloud 上传可能延迟；") +
                V3L("此状态不代表云端服务器已完成同步。")
        default:
            return V3L("恢复前验证归档，并创建当前数据的回滚备份。") +
                V3L("确认后仅暂存，新数据在下次完全退出并重新启动 App 时载入。")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let value = DateFormatter()
        value.dateStyle = .medium
        value.timeStyle = .short
        return value
    }()

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var config = UIListContentConfiguration.subtitleCell()
        let symbol: String
        switch (indexPath.section, indexPath.row) {
        case (0, _):
            config.text = V3L("立即备份并导出")
            config.secondaryText = V3L("同时生成本地备份；可保存到文件 App")
            symbol = "square.and.arrow.up"
        case (1, 0):
            config.text = ImpressV3BackupCoordinator.cloudFolderSelected
                ? V3L("重新选择备份文件夹") : V3L("连接 iCloud Drive 文件夹")
            config.secondaryText = V3L("仅在手动授权后自动写入副本")
            symbol = "cloud"
        case (1, 1):
            config.text = V3L("断开自动云盘备份")
            config.secondaryText = V3L("只清除本 App 的授权，不删除云盘文件")
            symbol = "xmark.icloud"
        default:
            config.text = V3L("从备份恢复")
            config.secondaryText = V3L("先验证，再确认；不会直接覆盖当前数据库")
            symbol = "arrow.uturn.backward"
        }
        config.image = UIImage(systemName: symbol)
        config.imageProperties.tintColor = ImpressV3Appearance.secondaryText
        config.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.isUserInteractionEnabled = !working
        ImpressV3Appearance.styleGroupedCell(cell)
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !working else { return }
        switch (indexPath.section, indexPath.row) {
        case (0, _): exportNow()
        case (1, 0): chooseCloudFolder()
        case (1, 1):
            ImpressV3BackupCoordinator.disconnectCloudFolder()
            tableView.reloadData()
        default: chooseRestoreArchive()
        }
    }

    private func exportNow() {
        working = true
        tableView.reloadData()
        Task { [weak self] in
            guard let self else { return }
            do {
                let local = try await ImpressV3BackupCoordinator.shared.createBackup(force: true)
                working = false
                tableView.reloadData()
                let picker = UIDocumentPickerViewController(
                    forExporting: [local], asCopy: true)
                present(picker, animated: true)
            } catch {
                working = false
                tableView.reloadData()
                report(error)
            }
        }
    }

    private func chooseCloudFolder() {
        let warning = UIAlertController(
            title: V3L("确认备份隐私范围"),
            message: V3L("Impress 备份 ZIP 当前没有密码加密，任何获得该文件的人都可能读取卡片、复习历史、理解记录与提示词。请选择仅自己可以访问的 iCloud Drive 文件夹。授权后将尝试静默复制，上传到 iCloud 服务器是否完成由系统决定。"),
            preferredStyle: .alert)
        warning.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        warning.addAction(UIAlertAction(title: V3L("继续选择文件夹"), style: .default) {
            [weak self] _ in self?.presentCloudFolderPicker()
        })
        present(warning, animated: true)
    }

    private func presentCloudFolderPicker() {
        pendingPurpose = .cloudFolder
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.folder], asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func chooseRestoreArchive() {
        pendingPurpose = .restoreArchive
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.zip], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingPurpose = nil
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        defer { pendingPurpose = nil }
        guard let url = urls.first, let purpose = pendingPurpose else { return }
        switch purpose {
        case .cloudFolder:
            do {
                try ImpressV3BackupCoordinator.connectCloudFolder(url)
                tableView.reloadData()
                // Existing local data is mirrored on the next backup check;
                // first connect also creates an authorized verified snapshot.
                Task {
                    do {
                        _ = try await ImpressV3BackupCoordinator.shared.createBackup(force: true)
                        self.tableView.reloadData()
                    } catch { self.report(error) }
                }
            } catch { report(error) }
        case .restoreArchive:
            // Keep the picker-provided temporary file while an explicit
            // recovery confirmation is displayed.
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("ImpressRestore-" + UUID().uuidString + ".zip")
            do {
                try FileManager.default.copyItem(at: url, to: copy)
                validateRestore(copy)
            } catch { report(error) }
        }
    }

    private func validateRestore(_ archive: URL) {
        working = true
        tableView.reloadData()
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.working = false
                self.tableView.reloadData()
            }
            do {
                let preview = try await ImpressV3BackupCoordinator.shared.inspectRecovery(archive)
                let info = "日期：\(Self.dateFormatter.string(from: preview.manifest.createdAt))\n" +
                    "卡片：\(preview.cardCount) 张\n" +
                    "复习历史：\(preview.reviewCount) 条\n" +
                    "理解记录：\(preview.learningCount) 条\n" +
                    (preview.calibrationCount.map { "校准历史：\($0) 天（V3.2）\n" }
                     ?? "旧版备份不含校准历史；保留本机现有校准数据。\n") +
                    "提示词模板：已验证\n" +
                    "Obsidian 外部原件不会被修改。\n\n" +
                    "当前数据会先创建回滚备份，恢复在下次重新启动时生效。"
                let alert = UIAlertController(
                    title: V3L("确认恢复 Impress 数据？"),
                    message: info, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel) { _ in
                    try? FileManager.default.removeItem(at: archive)
                })
                alert.addAction(UIAlertAction(title: V3L("确认恢复"), style: .destructive) {
                    [weak self] _ in
                    guard let self else { return }
                    self.stageRestore(archive)
                })
                present(alert, animated: true)
            } catch {
                try? FileManager.default.removeItem(at: archive)
                report(error)
            }
        }
    }

    private func stageRestore(_ archive: URL) {
        working = true
        tableView.reloadData()
        Task { [weak self] in
            guard let self else { return }
            defer {
                try? FileManager.default.removeItem(at: archive)
                working = false
                tableView.reloadData()
            }
            do {
                try await ImpressV3BackupCoordinator.shared.stageRecovery(archive)
                let alert = UIAlertController(
                    title: V3L("恢复文件已安全暂存"),
                    message: V3L("请完全退出 Impress，再重新打开。恢复前的数据库备份已保留；不会触碰 Obsidian 源文件。"),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
                present(alert, animated: true)
            } catch { report(error) }
        }
    }

    private func report(_ error: Error) {
        let alert = UIAlertController(title: V3L("操作未完成"),
            message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        if presentedViewController == nil { present(alert, animated: true) }
    }
}
