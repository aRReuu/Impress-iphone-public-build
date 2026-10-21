import SwiftUI
import WidgetKit
import UIKit
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

private struct CalibrationEntry: TimelineEntry {
    let date: Date
    let period: CalibrationWidgetPeriod
    let overview: CalibrationWidgetOverview?
    let plot: CalibrationWidgetCartesianPlot?
}

private struct CalibrationProvider: TimelineProvider {
    let period: CalibrationWidgetPeriod

    func placeholder(in context: Context) -> CalibrationEntry {
        CalibrationEntry(date: Date(), period: period, overview: nil, plot: nil)
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
        else { return CalibrationEntry(date: now, period: period, overview: nil, plot: nil) }
        let plot = CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: period, at: now, calendar: Calendar.current)
        return CalibrationEntry(date: now, period: period, overview: overview, plot: plot)
    }
}

/// SwiftUI only embeds a snapshot produced by the SAME UIKit/CoreGraphics
/// renderer invoked in ImpressCalibrationTrendChart.draw().
private struct SharedCartesianChart: View {
    @Environment(\.colorScheme) private var scheme
    let plot: CalibrationWidgetCartesianPlot
    let period: CalibrationWidgetPeriod

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 48 && geometry.size.height >= 48 {
                let labels = period == .year
                    ? plot.tickLabels.map {
                        $0.replacingOccurrences(
                            of: "月", with: WidgetWords.tr("月", "月", "Month"))
                    } : plot.tickLabels
                Image(uiImage: CalibrationCartesianTrendRenderer.image(
                    size: geometry.size, values: plot.values,
                    smooth: plot.smooth, tickLabels: labels,
                    palette: .semantic,
                    font: UIFont.preferredFont(forTextStyle: .caption2),
                    traitCollection: UITraitCollection(
                        userInterfaceStyle: scheme == .dark ? .dark : .light)))
                    .resizable()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetWords.tr(
            "二维净分趋势：灰色每日／月均分，蓝色均线；空白日期无分数",
            "二維淨分趨勢：灰色每日／月均分、藍色均線；空白日期無分數",
            "Cartesian net-score trend: gray values and blue moving average; gaps are unscored"))
    }
}

private struct CalibrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalibrationEntry

    private var small: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 3 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(WidgetWords.widgetName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(WidgetWords.title(entry.period))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let overview = entry.overview, let plot = entry.plot {
                primaryAssessment(overview)
                SharedCartesianChart(plot: plot, period: entry.period)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                HStack(spacing: 4) {
                    Text("\(WidgetWords.completed) \(finalized(overview))")
                    Spacer(minLength: 2)
                    Text("\(WidgetWords.partial) \(partial(overview))")
                }
                .font(.system(size: small ? 9 : 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            } else {
                Spacer(minLength: 2)
                Text(WidgetWords.noData)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
        }
        .padding(small ? 9 : 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemGroupedBackground)
        }
        .widgetURL(URL(string: "impress://calibration/\(entry.period.rawValue)"))
    }

    @ViewBuilder
    private func primaryAssessment(_ overview: CalibrationWidgetOverview) -> some View {
        switch entry.period {
        case .week:
            let today = overview.weekDays.last
            Text(today?.state == .finalized
                 ? WidgetWords.completed
                 : "\(WidgetWords.today) \(today?.assessedCount ?? 0)/5")
                .font(.system(size: small ? 18 : 22, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        case .month:
            Text("\(CalibrationWidgetOverview.assessedDays(overview.monthDays))/30 \(WidgetWords.days)")
                .font(.system(size: small ? 18 : 22, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        case .year:
            let assessed = overview.yearMonths.reduce(0) { $0 + $1.assessedDays }
            Text("\(assessed) \(WidgetWords.days)")
                .font(.system(size: small ? 18 : 22, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func finalized(_ overview: CalibrationWidgetOverview) -> Int {
        switch entry.period {
        case .week: return CalibrationWidgetOverview.finalizedDays(overview.weekDays)
        case .month: return CalibrationWidgetOverview.finalizedDays(overview.monthDays)
        case .year: return overview.yearMonths.reduce(0) { $0 + $1.finalizedDays }
        }
    }

    private func partial(_ overview: CalibrationWidgetOverview) -> Int {
        switch entry.period {
        case .week: return CalibrationWidgetOverview.partialDays(overview.weekDays)
        case .month: return CalibrationWidgetOverview.partialDays(overview.monthDays)
        case .year: return overview.yearMonths.reduce(0) { $0 + $1.partialDays }
        }
    }
}

private struct CalibrationPeriodWidget: Widget {
    let period: CalibrationWidgetPeriod

    // Xcode 27 / WidgetKit requires Widget.init() even for multi-kind bundles.
    // The bundle explicitly selects .week / .month / .year via init(period:).
    init() { self.period = .week }
    init(period: CalibrationWidgetPeriod) { self.period = period }

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
