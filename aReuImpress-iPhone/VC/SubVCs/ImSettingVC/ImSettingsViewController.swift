//
//  ImSettingsViewController.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 10/5/25.
//

// MARK: - Settings Enums and Configuration
/// 设置界面枚举定义，提供类型安全的section和cell管理
enum SettingsSection {
    /// 自动生成设置组
    case autoGenerate

    /// 系统提示词设置组
    case systemPrompt
    /// 权限管理组
    case permissions
    /// 调试设置组
    case debug
    /// 壁纸设置组
    case wallpaper
    /// 通知设置组
    case notifications
}

// MARK: - Settings Row Enums
extension SettingsSection {
    /// 自动生成设置的行类型
    enum AutoGenerateRow: Int, CaseIterable {
        /// 自动生成开关
        case toggle = 0
        /// 间隔时间滑块
        case interval = 1
    }



    /// 系统提示词设置的行类型
    enum SystemPromptRow: Int, CaseIterable {
        /// 编辑系统提示词
        case editPrompt = 0
    }

    /// 权限管理的行类型
    enum PermissionsRow: Int, CaseIterable {
        /// 导出到iCloud
        case exportToIcloud = 0
    }

    /// 调试设置的行类型
    enum DebugRow: Int, CaseIterable {
        /// 模拟数据开关
        case mockData = 0
        /// Explicit V3 pilot: Debug only, never rewrites Release or old WCDB.
        case v3ReviewPilot = 1
    }

    /// 墙纸设置的行类型
    enum WallpaperRow: Int, CaseIterable {
        /// 墙纸开关
        case toggle = 0
    }

    /// 通知设置的行类型
    enum NotificationsRow: Int, CaseIterable {
        /// 提醒间隔时间
        case reminderInterval = 0
    }


}

// MARK: - Settings Configuration
/// 设置界面配置结构体，用于定制显示的section和cells
struct SettingsConfiguration {
    /// 要显示的section列表，可以修改顺序或隐藏某些section
    var displaySections: [SettingsSection] {
        #if DEBUG
        return [
            // 滑动控件类
            .notifications,
            // 开关类
            // 目前使用高频,需要斟酌
//            .autoGenerate,
            .wallpaper,
            .debug,
            // 控制业务逻辑类
            .systemPrompt
//            .permissions
        ]
        #else
        return [
            // 滑动控件类
            .notifications,
            // 开关类
            // 目前使用高频,需要斟酌
//            .autoGenerate,
            .wallpaper,
            // 控制业务逻辑类
            .systemPrompt
//            .permissions
        ]
        #endif
    }

    /// 自动生成section中要显示的rows，可以修改顺序或隐藏某些row
    var autoGenerateRows: [SettingsSection.AutoGenerateRow] = [.toggle, .interval]

    /// 系统提示词section中要显示的rows
    var systemPromptRows: [SettingsSection.SystemPromptRow] = [.editPrompt]
    /// 权限管理section中要显示的rows，可以修改顺序或隐藏某些row
    var permissionsRows: [SettingsSection.PermissionsRow] = [.exportToIcloud] // [.exportToIcloud]
    /// 调试设置section中要显示的rows
    var debugRows: [SettingsSection.DebugRow] = [.mockData, .v3ReviewPilot]
    /// 墙纸设置section中要显示的rows
    var wallpaperRows: [SettingsSection.WallpaperRow] = [.toggle]
    /// 通知设置section中要显示的rows
    var notificationsRows: [SettingsSection.NotificationsRow] = [.reminderInterval]
    /// 默认配置，显示所有section和rows
    static let `default` = SettingsConfiguration()
}

import UIKit
import Combine

class ImSettingsViewController: ImBaseViewController {

    /// 设置界面配置，可以修改此配置来定制显示的section和cell
    private lazy var configuration: SettingsConfiguration = {
        var config = SettingsConfiguration.default
        return config
    }()

    private let viewModel = ImSettingsViewModel()
    private var cancellables = Set<AnyCancellable>()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = bgColor
        tableView.tintColor = funBtnColor
        tableView.register(ImSettingSwitchCell.self, forCellReuseIdentifier: ImSettingSwitchCell.identifier)
        tableView.register(ImSettingSliderCell.self, forCellReuseIdentifier: ImSettingSliderCell.identifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "defaultCell")
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }

    private func setupUI() {
        title = "设置"
        view.backgroundColor = bgColor
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.delegate = self
        tableView.dataSource = self
    }

    private func setupBindings() {
        viewModel.$isAutoGenerateEnabled
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$intervalHours
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)



        viewModel.$systemPrompt
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$isMockDataEnabled
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$reminderMinutes
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$isWallpaperEnabled
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }
}

// MARK: - UITableViewDelegate & DataSource
extension ImSettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return configuration.displaySections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < configuration.displaySections.count else { return 0 }
        switch configuration.displaySections[section] {
        case .autoGenerate:
            // 只有开关开启时才显示间隔时间滑块
            if viewModel.isAutoGenerateEnabled {
                return configuration.autoGenerateRows.count
            } else {
                return 1 // 只显示开关
            }

        case .systemPrompt:
            return configuration.systemPromptRows.count
        case .permissions:
            return 1 // 固定1个权限管理选项
        case .debug:
            return configuration.debugRows.count
        case .wallpaper:
            return configuration.wallpaperRows.count
        case .notifications:
            return configuration.notificationsRows.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section < configuration.displaySections.count else {
            return UITableViewCell()
        }

        let sectionType = configuration.displaySections[indexPath.section]

        switch sectionType {
        case .autoGenerate:
            guard indexPath.row < configuration.autoGenerateRows.count else {
                return UITableViewCell()
            }
            let rowType = configuration.autoGenerateRows[indexPath.row]

            switch rowType {
            case .toggle:
                let cell = tableView.dequeueReusableCell(withIdentifier: ImSettingSwitchCell.identifier, for: indexPath) as! ImSettingSwitchCell
                cell.configure(title: "自动生成问题", isOn: viewModel.isAutoGenerateEnabled)
                cell.switchValueChanged = { [weak self] isOn in
                    self?.viewModel.setAutoGenerateEnabled(isOn)
                }
                cell.selectionStyle = .none
                return cell

            case .interval:
                let cell = tableView.dequeueReusableCell(withIdentifier: ImSettingSliderCell.identifier, for: indexPath) as! ImSettingSliderCell
                cell.configure(title: "间隔时间", currentValue: viewModel.intervalHours, minValue: 1, maxValue: 24)
                cell.sliderValueChanged = { [weak self] value in
                    self?.viewModel.setIntervalHours(value)
                }
                cell.selectionStyle = .none
                return cell
            }



        case .systemPrompt:
            guard indexPath.row < configuration.systemPromptRows.count else {
                return UITableViewCell()
            }
            let rowType = configuration.systemPromptRows[indexPath.row]

            switch rowType {
            case .editPrompt:
                let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
                cell.textLabel?.text = "系统提示词编辑"
                cell.detailTextLabel?.text = String(viewModel.systemPrompt.prefix(20)) + (viewModel.systemPrompt.count > 20 ? "..." : "")
                cell.detailTextLabel?.textColor = .secondaryLabel
                cell.detailTextLabel?.font = .systemFont(ofSize: 14)
                cell.detailTextLabel?.numberOfLines = 1
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .none
                return cell
            }

        case .permissions:
//            guard indexPath.row < configuration.permissionsRows.count else {
//                return UITableViewCell()
//            }
//
//            let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
//            cell.textLabel?.text = "导出到iCloud"
//            cell.detailTextLabel?.text = "将ImpressDB文件夹导出到iCloud Drive的Download文件夹"
//            cell.detailTextLabel?.textColor = .secondaryLabel
//            cell.detailTextLabel?.font = .systemFont(ofSize: 12)
//            cell.detailTextLabel?.numberOfLines = 1
//            cell.accessoryType = .disclosureIndicator
//            cell.selectionStyle = .none
//            return cell
            return UITableViewCell()
        case .debug:
            guard indexPath.row < configuration.debugRows.count else {
                return UITableViewCell()
            }
            let rowType = configuration.debugRows[indexPath.row]

            switch rowType {
            case .mockData:
                let cell = tableView.dequeueReusableCell(withIdentifier: ImSettingSwitchCell.identifier, for: indexPath) as! ImSettingSwitchCell
                cell.configure(title: "模拟数据", isOn: viewModel.isMockDataEnabled)
                cell.switchValueChanged = { [weak self] isOn in
                    self?.viewModel.isMockDataEnabled = isOn
                }
                cell.selectionStyle = .none
                return cell
            case .v3ReviewPilot:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: ImSettingSwitchCell.identifier,
                    for: indexPath) as! ImSettingSwitchCell
                cell.configure(title: "V3.1 闪卡测试版（重启生效）",
                               isOn: ImpressV3ReviewEnvironment.pilotEnabled)
                cell.switchValueChanged = { [weak self] enabled in
                    #if DEBUG
                    ImpressV3ReviewEnvironment.pilotEnabled = enabled
                    let alert = UIAlertController(
                        title: enabled ? "V3.1 测试版已启用" : "旧版闪卡已恢复",
                        message: "退出并重新打开 App 后生效。原有旧版卡片数据不会迁移或删除。",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(alert, animated: true)
                    #endif
                }
                cell.selectionStyle = .none
                return cell
            }

        case .wallpaper:
            guard indexPath.row < configuration.wallpaperRows.count else {
                return UITableViewCell()
            }
            let rowType = configuration.wallpaperRows[indexPath.row]

            switch rowType {
            case .toggle:
                let cell = tableView.dequeueReusableCell(withIdentifier: ImSettingSwitchCell.identifier, for: indexPath) as! ImSettingSwitchCell
                cell.configure(title: "显示壁纸", isOn: viewModel.isWallpaperEnabled)
                cell.switchValueChanged = { [weak self] isOn in
                    self?.viewModel.isWallpaperEnabled = isOn
                }
                cell.selectionStyle = .none
                return cell
            }

        case .notifications:
            guard indexPath.row < configuration.notificationsRows.count else {
                return UITableViewCell()
            }
            let rowType = configuration.notificationsRows[indexPath.row]

            switch rowType {
            case .reminderInterval:
                let cell = tableView.dequeueReusableCell(withIdentifier: ImSettingSliderCell.identifier, for: indexPath) as! ImSettingSliderCell
                cell.configure(title: "提醒间隔", currentValue: CGFloat(viewModel.reminderMinutes), minValue: 10, maxValue: 1440, unitType: .time)
                cell.sliderValueChanged = { [weak self] value in
                    self?.viewModel.setReminderMinutes(Int(value))
                }
                cell.selectionStyle = .none
                return cell
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section < configuration.displaySections.count else { return 44 }
        let sectionType = configuration.displaySections[indexPath.section]



        if sectionType == .notifications && indexPath.row < configuration.notificationsRows.count && configuration.notificationsRows[indexPath.row] == .reminderInterval {
            return 70 // 增加提醒间隔设置行的行高，确保滑块有足够空间
        }

        return 44
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < configuration.displaySections.count else { return nil }
        switch configuration.displaySections[section] {
        case .autoGenerate:
            return "自动生成设置"

        case .systemPrompt:
            return "系统提示词"
        case .permissions:
            return "权限管理"
        case .debug:
            return "调试设置"
        case .wallpaper:
            return "壁纸设置"
        case .notifications:
            return "通知设置"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section < configuration.displaySections.count else { return nil }
        switch configuration.displaySections[section] {
        case .autoGenerate:
            return "启用后将定期自动从笔记中生成问题并保存到标记问题列表中。"
        case .permissions, .systemPrompt, .debug, .wallpaper, .notifications:
            return nil
        }
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section < configuration.displaySections.count else { return }

        let sectionType = configuration.displaySections[indexPath.section]

//        if sectionType == .permissions,
//           indexPath.row < configuration.permissionsRows.count {
//            // 导出到iCloud
//            loadShare.show()
//            ImiCloudBackupManager.shared.performManualExport(from: self) { [weak self] error in
//                loadShare.hide()
//                if let error = error {
//                    let alert = UIAlertController(title: "导出失败", message: error.localizedDescription, preferredStyle: .alert)
//                    alert.addAction(UIAlertAction(title: "确定", style: .default))
//                    self?.present(alert, animated: true)
//                } else {
//                    let alert = UIAlertController(title: "导出成功",
//                                                message: "ImpressDB文件夹已成功导出到iCloud Drive",
//                                                preferredStyle: .alert)
//                    alert.addAction(UIAlertAction(title: "确定", style: .default))
//                    self?.present(alert, animated: true)
//                }
//            }
//        } else
        if sectionType == .systemPrompt,
                  indexPath.row < configuration.systemPromptRows.count {
            let rowType = configuration.systemPromptRows[indexPath.row]
            switch rowType {
            case .editPrompt:
                // 系统提示词编辑
                let systemPromptVC = ImSystemPromptViewController(viewModel: viewModel)
                navigationController?.pushViewController(systemPromptVC, animated: true)
            }
        }
        // 其他section没有点击处理
    }
}
