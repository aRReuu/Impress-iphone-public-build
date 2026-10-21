import SwiftUI
import WidgetKit
import ImpressReviewCore

private enum WidgetWords {
    private static var traditional: Bool {
        let id = Locale.current.identifier.lowercased()
        return id.contains("hant") || id.contains("_tw") || id.contains("_hk") ||
            id.contains("-tw") || id.contains("-hk")
    }
    private static var chinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
    static func tr(_ simplified: String, _ traditional: String, _ english: String) -> String {
        chinese ? (self.traditional ? traditional : simplified) : english
    }
    static func title(_ period: CalibrationWidgetPeriod) -> String {
        switch period {
        case .week: return tr("近7日", "近7日", "Last 7 days")
        case .month: return tr("近30日", "近30日", "Last 30 days")
        case .year: return tr("本年度", "本年度", "This year")
        }
    }
    static var completed: String { tr("已评估", "已評估", "Assessed") }
    static var partial: String { tr("部分", "部分", "Partial") }
    static var unknown: String { tr("未记录", "未記錄", "Unrecorded") }
    static var today: String { tr("今日", "今日", "Today") }
    static var days: String { tr("天", "天", "days") }
    static var noData: String {
        tr("打开 Impress 查看评估记录", "開啟 Impress 查看評估記錄",
           "Open Impress to load assessments")
    }
    static var widgetName: String { tr("校准器", "校準器", "Calibration") }
    static var lastUpdate: String { tr("快照", "快照", "Snapshot") }
}

private extension CalibrationWidgetDayState {
    var color: Color {
        switch self {
        case .finalized: return .green
        case .partial: return .orange
        case .unrecorded: return Color.secondary.opacity(0.25)
        }
    }
}

private struct CalibrationEntry: TimelineEntry {
    let date: Date
    let period: CalibrationWidgetPeriod
    let overview: CalibrationWidgetOverview?
}

private struct CalibrationProvider: TimelineProvider {
    let period: CalibrationWidgetPeriod

    func placeholder(in context: Context) -> CalibrationEntry {
        CalibrationEntry(date: Date(), period: period, overview: nil)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (CalibrationEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<CalibrationEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [makeEntry(at: now)], policy: .after(nextMidnight)))
    }

    private func makeEntry(at now: Date) -> CalibrationEntry {
        guard let root = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.areu.impress"),
              let data = try? Data(contentsOf: root.appendingPathComponent(
                "calibration-widget-v1.json")),
              let snapshot = try? JSONDecoder().decode(
                CalibrationWidgetSnapshot.self, from: data),
              let overview = CalibrationWidgetProjection.overview(
                from: snapshot, at: now, calendar: Calendar.current)
        else { return CalibrationEntry(date: now, period: period, overview: nil) }
        return CalibrationEntry(date: now, period: period, overview: overview)
    }
}

private struct StatusDot: View {
    let state: CalibrationWidgetDayState
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(state.color)
            .frame(maxWidth: .infinity)
            .frame(height: 11)
            .accessibilityLabel({
                switch state {
                case .finalized: return WidgetWords.completed
                case .partial: return WidgetWords.partial
                case .unrecorded: return WidgetWords.unknown
                }
            }())
    }
}

private struct CalibrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalibrationEntry

    private func ratioText(_ days: [CalibrationWidgetDay]) -> String {
        "\(CalibrationWidgetOverview.assessedDays(days))/\(days.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(WidgetWords.widgetName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(WidgetWords.title(entry.period))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            if let data = entry.overview {
                content(for: data)
            } else {
                Spacer(minLength: 4)
                Text(WidgetWords.noData)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
        }
        .padding(family == .systemSmall ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
        .widgetURL(URL(string: "impress://calibration/\(entry.period.rawValue)"))
    }

    @ViewBuilder
    private func content(for overview: CalibrationWidgetOverview) -> some View {
        switch entry.period {
        case .week:
            weekContent(overview)
        case .month:
            monthContent(overview)
        case .year:
            yearContent(overview)
        }
    }

    @ViewBuilder
    private func weekContent(_ overview: CalibrationWidgetOverview) -> some View {
        let today = overview.weekDays.last
        HStack(alignment: .firstTextBaseline) {
            Text(today?.state == .finalized
                 ? WidgetWords.completed : "\(WidgetWords.today) \(today?.assessedCount ?? 0)/5")
                .font(.system(size: family == .systemSmall ? 23 : 27, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
            if family == .systemMedium, let score = today?.netScore {
                Text(score > 0 ? "+\(score)" : "\(score)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        HStack(spacing: family == .systemSmall ? 4 : 7) {
            ForEach(overview.weekDays) { day in
                VStack(spacing: 6) {
                    if family == .systemMedium {
                        Text(String(day.dayID.suffix(5)))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    StatusDot(state: day.state)
                }
            }
        }
        Spacer(minLength: 2)
        HStack {
            Text("\(WidgetWords.completed) \(CalibrationWidgetOverview.finalizedDays(overview.weekDays))")
            Spacer(minLength: 4)
            Text("\(WidgetWords.partial) \(CalibrationWidgetOverview.partialDays(overview.weekDays))")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private func monthContent(_ overview: CalibrationWidgetOverview) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ratioText(overview.monthDays))
                .font(.system(size: family == .systemSmall ? 26 : 28, weight: .semibold))
            Text(WidgetWords.days).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 2)
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4),
                                 count: 10), spacing: 6) {
            ForEach(overview.monthDays) { day in
                StatusDot(state: day.state)
            }
        }
        Spacer(minLength: 0)
        if family == .systemMedium {
            legend
        } else {
            Text("\(WidgetWords.completed) \(CalibrationWidgetOverview.finalizedDays(overview.monthDays))  ·  \(WidgetWords.partial) \(CalibrationWidgetOverview.partialDays(overview.monthDays))")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private func yearContent(_ overview: CalibrationWidgetOverview) -> some View {
        let total = overview.yearMonths.reduce(0) { $0 + $1.assessedDays }
        HStack(alignment: .firstTextBaseline) {
            Text("\(total)")
                .font(.system(size: family == .systemSmall ? 25 : 28, weight: .semibold))
            Text(WidgetWords.days).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 2)
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5),
                                 count: family == .systemSmall ? 6 : 12), spacing: 7) {
            ForEach(overview.yearMonths) { month in
                VStack(spacing: 3) {
                    Text("\(month.month)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(month.elapsedDays == 0
                              ? Color.secondary.opacity(0.08)
                              : (month.assessedDays > 0 ? Color.green : Color.secondary.opacity(0.25)))
                        .frame(height: 9)
                    if family == .systemMedium {
                        Text("\(month.assessedDays)/\(month.elapsedDays)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                    }
                }
            }
        }
        Spacer(minLength: 0)
        if family == .systemMedium { legend }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Label(WidgetWords.completed, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Label(WidgetWords.partial, systemImage: "circle.lefthalf.filled")
                .foregroundStyle(.orange)
            Text(WidgetWords.unknown).foregroundStyle(.secondary)
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }
}

private struct CalibrationPeriodWidget: Widget {
    let period: CalibrationWidgetPeriod
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "impress.calibration.\(period.rawValue)",
            provider: CalibrationProvider(period: period)
        ) { entry in
            CalibrationWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetWords.widgetName + " · " + WidgetWords.title(period))
        .description(WidgetWords.tr(
            "以行为评估与记录覆盖为主", "以行為評估與記錄覆蓋為主",
            "Assessment coverage, not a scorecard"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ImpressCalibrationWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalibrationPeriodWidget(period: .week)
        CalibrationPeriodWidget(period: .month)
        CalibrationPeriodWidget(period: .year)
    }
}
