import UIKit
import ImpressReviewCore

/// Five-indicator daily check-in + week/month/year trends.
/// No separate FSRS scoring, no native AI, no edits to Obsidian files.
@MainActor
final class ImpressCalibrationViewController: UITableViewController {
    private let store = ImpressCalibrationLocalStore.shared
    private var checkIn: CalibrationDayCheckIn?
    private let header = UIView()
    private let headline = UILabel()
    private let detail = UILabel()
    private let chart = ImpressCalibrationTrendChart()
    private let period = UISegmentedControl(items: [V3L("周"), V3L("月"), V3L("年")])
    private var loading = false

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("校准")
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = ImpressV3Appearance.page
        tableView.backgroundColor = ImpressV3Appearance.page
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 68
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "indicator")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: V3L("编辑目标"), style: .plain, target: self, action: #selector(editGoals))
        configureHeader()
        period.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        Task { await refresh() }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = V3L("校准")
        navigationItem.rightBarButtonItem?.title = V3L("编辑目标")
        for (index, key) in [V3L("周"), V3L("月"), V3L("年")].enumerated() {
            period.setTitle(V3L(key), forSegmentAt: index)
        }
        Task { await refresh() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if abs(header.frame.width - tableView.bounds.width) > 0.5 {
            header.frame.size.width = tableView.bounds.width
            tableView.tableHeaderView = header
        }
    }

    @objc private func appBecameActive() {
        Task { await refresh() }
    }

    private func configureHeader() {
        header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 290)
        headline.font = ImpressV3Appearance.Typography.heading
        headline.adjustsFontForContentSizeCategory = true
        headline.textColor = ImpressV3Appearance.primaryText
        headline.text = V3L("今日尚未完成五项评估")
        headline.numberOfLines = 2
        detail.font = ImpressV3Appearance.Typography.supporting
        detail.adjustsFontForContentSizeCategory = true
        detail.textColor = ImpressV3Appearance.secondaryText
        detail.numberOfLines = 2
        detail.text = V3L("完成一次评估后，计算今日净得分。")
        period.selectedSegmentIndex = 0
        period.accessibilityIdentifier = "impress.calibration.period"
        ImpressV3Appearance.styleSegmentedControl(period, prominent: false)
        chart.accessibilityIdentifier = "impress.calibration.trend"
        let container = UIStackView(arrangedSubviews: [headline, detail, period, chart])
        container.axis = .vertical
        container.spacing = ImpressV3Appearance.Metrics.rowSpacing
        container.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: header.leadingAnchor,
                                               constant: ImpressV3Appearance.Metrics.screenInset),
            container.trailingAnchor.constraint(equalTo: header.trailingAnchor,
                                                constant: -ImpressV3Appearance.Metrics.screenInset),
            container.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8),
            period.heightAnchor.constraint(greaterThanOrEqualToConstant:
                                           ImpressV3Appearance.Metrics.controlHeight),
            chart.heightAnchor.constraint(greaterThanOrEqualToConstant: 174)
        ])
        tableView.tableHeaderView = header
    }

    @objc private func periodChanged() { Task { await refreshChart() } }

    /// A Widget tap navigates to the existing controller, not a parallel score UI.
    func selectWidgetPeriod(_ selected: CalibrationWidgetPeriod) {
        loadViewIfNeeded()
        switch selected {
        case .week: period.selectedSegmentIndex = 0
        case .month: period.selectedSegmentIndex = 1
        case .year: period.selectedSegmentIndex = 2
        }
        Task { await refreshChart() }
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let today = try await store.checkIn()
            checkIn = today
            let pending = today.pendingIndicators.count
            let summary = try today.finalizedScore()
            if pending > 0 {
                headline.text = String(format: V3L("今日待评估 %d / 5 项"), pending)
                detail.text = "未评估不会自动扣分。情绪仅作观察，不参与加减分。"
            } else if let net = summary.netScore {
                headline.text = String(format: V3L("今日净分 %@"), (net > 0 ? "+" : "") + String(net))
                detail.text = "五项均已处理 · 本日提醒可停止 · 不代表个人价值"
            } else {
                headline.text = "今日已完成评估"
                detail.text = "今天没有可计分任务，休息与豁免不会产生扣分。"
            }
            tableView.reloadData()
            await refreshChart()
            ImpressCalibrationReminderCoordinator.shared.requestReconciliation()
        } catch {
            showError(error)
        }
    }

    private func refreshChart() async {
        do {
            let records = try await store.trendRecords()
            let cal = Calendar.current
            let now = Date()
            let currentID = CalibrationDayCheckIn.dayID(for: now, calendar: cal)
            if period.selectedSegmentIndex == 2 {
                let year = cal.component(.year, from: now)
                let months = try CalibrationScoreCore.monthlyTrend(records, year: year)
                let values = months.map(\.averageDailyScore)
                var averages = [Double?]()
                for index in values.indices {
                    let recent = values[max(0, index-2)...index].compactMap { $0 }
                    averages.append(values[index] == nil ? nil :
                        recent.reduce(0, +) / Double(recent.count))
                }
                chart.update(values: values, smooth: averages, title: "月均每日得分",
                             labels: months.map { String($0.month) + V3L("月") })
            } else {
                let length = period.selectedSegmentIndex == 0 ? 6 : 29
                let start = cal.date(byAdding: .day, value: -length, to: now)!
                let firstID = CalibrationDayCheckIn.dayID(for: start, calendar: cal)
                let days = try CalibrationScoreCore.dailyTrend(
                    records, from: firstID, through: currentID)
                chart.update(values: days.map { $0.netScore.map(Double.init) },
                             smooth: days.map(\.trailingSevenDayMean),
                             title: period.selectedSegmentIndex == 0 ?
                                "每日净分与7日均线" : "近30日净分与7日均线",
                             labels: days.map { String($0.dayID.suffix(5)) })
            }
        } catch {
            showError(error)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 5
        case 1: return 2
        default: return 1
        }
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return V3L("今日五项 · 点击进行评估")
        case 1: return V3L("额外行为修正（每种最多一次）")
        default: return V3L("未完成提醒")
        }
    }

    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "完成 +1 · 未完成 -1 · 休息或豁免 0。情绪仅观察；明确跳过也算已评估。"
        case 1: return "仅记录未在四项任务中计过分的额外行为，避免重复扣分。"
        default: return "经系统授权后，在 20:00、22:00 提醒；完成当日五项后撤销剩余提醒。iOS 允许用户清除系统通知，无法创建永久置顶通知。"
        }
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "indicator",
                                                 for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.secondaryTextProperties.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        if indexPath.section == 0 {
            let kind = CalibrationIndicator.allCases[indexPath.row]
            let names: [CalibrationIndicator: String] = [
                .sleep: V3L("早睡"), .exercise: V3L("运动"), .nutrition: V3L("饮食"),
                .mood: V3L("情绪"), .custom: V3L("自定义")]
            let icons: [CalibrationIndicator: String] = [
                .sleep: "moon.stars", .exercise: "figure.run",
                .nutrition: "fork.knife", .mood: "face.smiling", .custom: "slider.horizontal.3"]
            content.text = names[kind]
            content.image = UIImage(systemName: icons[kind] ?? "circle")
            content.imageProperties.tintColor = ImpressV3Appearance.secondaryText
            if let record = checkIn {
                if kind == .mood {
                    let status = record.moodAssessed
                        ? record.moodLevel.map { "已记录 \($0)/5（不计分）" } ?? "主动跳过（不计分）"
                        : "尚未记录"
                    content.secondaryText = status
                } else {
                    let status: String
                    switch record.outcome(for: kind) {
                    case .completed: status = "已完成 · +1"
                    case .missed: status = V3L("未完成 · -1")
                    case .excused: status = "休息 / 不适用 · 0"
                    case .unrecorded: status = V3L("待评估")
                    }
                    content.secondaryText = record.goalsSnapshot.title(for: kind) + " · " + status
                }
            } else { content.secondaryText = V3L("载入中…") }
            cell.accessibilityIdentifier = "impress.calibration.indicator." + kind.rawValue
        } else if indexPath.section == 1 {
            let positive = indexPath.row == 0
            content.text = positive ? V3L("额外加分 +1") : V3L("额外减分 -1")
            content.image = UIImage(systemName: positive ? "plus.circle" : "minus.circle")
            content.imageProperties.tintColor = ImpressV3Appearance.secondaryText
            let note = positive ? checkIn?.bonusNote : checkIn?.deductionNote
            content.secondaryText = note ?? V3L("没有记录")
        } else {
            content.text = V3L("未完成重复提醒")
            content.secondaryText = ImpressCalibrationReminderCoordinator.shared.isEnabled ?
                "已启用 · 每晚两次，完成即停止当天提醒" : "未启用 · 点击申请 iOS 通知权限"
            content.image = UIImage(systemName: "bell.badge")
            content.imageProperties.tintColor = ImpressV3Appearance.secondaryText
        }
        cell.contentConfiguration = content
        ImpressV3Appearance.styleGroupedCell(cell)
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !loading else { return }
        switch indexPath.section {
        case 0:
            let kind = CalibrationIndicator.allCases[indexPath.row]
            kind == .mood ? chooseMood() : chooseOutcome(for: kind)
        case 1: editExtra(positive: indexPath.row == 0)
        default: changeReminderMode()
        }
    }

    private func chooseOutcome(for kind: CalibrationIndicator) {
        let menu = UIAlertController(title: "评估 · " + (checkIn?.goalsSnapshot.title(for: kind) ?? ""),
                                     message: nil, preferredStyle: .actionSheet)
        let options: [(String, CalibrationTaskOutcome)] = [
            (V3L("完成 · +1"), .completed),
            (V3L("未完成 · -1"), .missed),
            (V3L("计划休息 / 不适用 · 0"), .excused),
            (V3L("清除记录"), .unrecorded)
        ]
        for (title, outcome) in options {
            menu.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.updateCheckIn { try $0.setOutcome(outcome, for: kind) }
            })
        }
        menu.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        // iPad must anchor action sheets; iPhone uses the same native menu.
        menu.popoverPresentationController?.sourceView = tableView
        menu.popoverPresentationController?.sourceRect = CGRect(
            x: tableView.bounds.midX, y: tableView.bounds.midY, width: 1, height: 1)
        present(menu, animated: true)
    }

    private func chooseMood() {
        let menu = UIAlertController(title: V3L("今日情绪 · 仅观察"),
                                     message: "不以心情好坏评价自己，不参与每日得分。",
                                     preferredStyle: .actionSheet)
        for value in (1...5).reversed() {
            menu.addAction(UIAlertAction(title: "记录 \(value) / 5", style: .default) {
                [weak self] _ in
                self?.updateCheckIn { try $0.setMood(value) }
            })
        }
        menu.addAction(UIAlertAction(title: V3L("今天跳过"), style: .default) { [weak self] _ in
            self?.updateCheckIn { try $0.setMood(nil, assessed: true) }
        })
        menu.addAction(UIAlertAction(title: V3L("清除评估"), style: .default) { [weak self] _ in
            self?.updateCheckIn { try $0.setMood(nil, assessed: false) }
        })
        menu.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        // iPad must anchor action sheets; iPhone uses the same native menu.
        menu.popoverPresentationController?.sourceView = tableView
        menu.popoverPresentationController?.sourceRect = CGRect(
            x: tableView.bounds.midX, y: tableView.bounds.midY, width: 1, height: 1)
        present(menu, animated: true)
    }

    private func updateCheckIn(_ mutate: @escaping (inout CalibrationDayCheckIn) throws -> Void) {
        Task {
            do {
                var entry = try await store.checkIn()
                try mutate(&entry)
                try await store.save(entry)
                await refresh()
            } catch { showError(error) }
        }
    }

    private func editExtra(positive: Bool) {
        let alert = UIAlertController(title: positive ? V3L("额外加分") : V3L("额外减分"),
                                      message: "只记录计划之外的具体行为，不能重复计算今日任务。",
                                      preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = V3L("简短说明（最多120字）")
            $0.text = positive ? self.checkIn?.bonusNote : self.checkIn?.deductionNote
        }
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            self?.updateCheckIn { try $0.setManualAdjustment(positive: positive, reason: nil) }
        })
        alert.addAction(UIAlertAction(title: V3L("保存"), style: .default) { [weak self] _ in
            let value = alert.textFields?.first?.text
            self?.updateCheckIn { try $0.setManualAdjustment(positive: positive, reason: value) }
        })
        present(alert, animated: true)
    }

    @objc private func editGoals() {
        Task {
            do {
                let values = try await store.goals()
                let alert = UIAlertController(title: V3L("编辑四项行为标准"),
                    message: "尚未完成的当日计划可调整；目标变化的项目会重新标为待评估。已完成的日期保留原目标。",
                    preferredStyle: .alert)
                for value in [values.sleep, values.exercise, values.nutrition, values.custom] {
                    alert.addTextField { $0.text = value }
                }
                alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
                alert.addAction(UIAlertAction(title: V3L("保存"), style: .default) { [weak self] _ in
                    guard let self = self, let fields = alert.textFields, fields.count == 4 else { return }
                    let goals = CalibrationGoals(sleep: fields[0].text ?? "",
                                                 exercise: fields[1].text ?? "",
                                                 nutrition: fields[2].text ?? "",
                                                 custom: fields[3].text ?? "")
                    Task {
                        do {
                            try await self.store.setGoals(goals)
                            await self.refresh()
                        } catch { self.showError(error) }
                    }
                })
                present(alert, animated: true)
            } catch { showError(error) }
        }
    }

    private func changeReminderMode() {
        if ImpressCalibrationReminderCoordinator.shared.isEnabled {
            ImpressCalibrationReminderCoordinator.shared.setEnabled(false)
            tableView.reloadData()
            return
        }
        Task {
            let granted = await ImpressCalibrationReminderCoordinator.shared
                .requestAuthorizationFromUserAction()
            if granted {
                ImpressCalibrationReminderCoordinator.shared.setEnabled(true)
                tableView.reloadData()
            } else {
                let alert = UIAlertController(
                    title: "通知没有开启",
                    message: "系统权限被关闭时，校准页面仍会保留未完成状态。可前往 iOS 设置启用通知。",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: V3L("知道了"), style: .default))
                present(alert, animated: true)
            }
        }
    }

    private func showError(_ error: Error) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: V3L("校准数据未保存"),
                                      message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(alert, animated: true)
    }
}

/// Small native chart: calendar gaps are real gaps, and the 7-day mean never
/// silently treats missing entries as failures. Semantic UIColors adapt to theme.
private final class ImpressCalibrationTrendChart: UIView {
    private var values: [Double?] = []
    private var smooth: [Double?] = []
    private var descriptionText = "还没有校准记录"
    private var tickLabels: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    func update(values: [Double?], smooth: [Double?], title: String,
                labels: [String]) {
        self.values = values
        self.smooth = smooth
        self.tickLabels = labels
        descriptionText = title
        accessibilityLabel = title + "，" + values.compactMap { $0 }.count.description + "条有效记录"
        setNeedsDisplay()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        CalibrationCartesianTrendRenderer.draw(
            in: rect, context: context,
            values: values, smooth: smooth, tickLabels: tickLabels,
            palette: CalibrationCartesianPalette(
                axis: ImpressV3Appearance.divider,
                secondary: ImpressV3Appearance.secondaryText,
                accent: ImpressV3Appearance.accent),
            font: ImpressV3Appearance.Typography.micro,
            traitCollection: traitCollection)
    }
}
