import Charts
import SwiftUI
import Word7000Core

/// Learning actions per day (or per week, for 90 days), stacked by kind in
/// the same colors as Today's rows: blue words, indigo quizzes, green speaking.
struct HistoryActivityChart: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var activity: [DailyLearningActivity]
    var chartHeight: CGFloat = 180
    /// For "我": period totals and the bars, no selection.
    var compact = false
    @State private var selection: String?
    @State private var inspectedDay: String?

    enum Kind: String, CaseIterable, Identifiable {
        case words, quiz, speaking
        var id: Self { self }
        var label: String {
            switch self {
            case .words: L.t("單字", "Words")
            case .quiz: L.t("測驗", "Quizzes")
            case .speaking: L.t("口說", "Speaking")
            }
        }
        var color: Color {
            switch self {
            case .words: Palette.accent
            case .quiz: Palette.chinese
            case .speaking: Palette.known
            }
        }
        func count(in day: DailyLearningActivity) -> Int {
            switch self {
            case .words: day.words
            case .quiz: day.other
            case .speaking: day.speaking
            }
        }
    }

    private struct Segment: Identifiable {
        var day: DailyLearningActivity
        var kind: Kind
        var id: String { "\(day.date)-\(kind.rawValue)" }
        var count: Int { kind.count(in: day) }
    }

    /// 90 days read better as 13 weeks than as 90 thin bars.
    private var bars: [DailyLearningActivity] {
        activity.count > 31 ? DailyLearningActivity.weekly(activity) : activity
    }

    private var weekly: Bool { activity.count > 31 }

    private var segments: [Segment] {
        bars.flatMap { day in Kind.allCases.map { Segment(day: day, kind: $0) } }
    }

    private var selectedIndex: Int? {
        guard let date = inspectedDay ?? selection else { return nil }
        return bars.firstIndex { $0.date == date }
    }

    private var ticks: [String] {
        if bars.count <= 7 { return bars.map(\.date) }
        let step = weekly ? 4 : 7
        return stride(from: bars.count - 1, through: 0, by: -step).reversed().map { bars[$0].date }
    }

    private var hasActivity: Bool { activity.contains { $0.total > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if compact {
                periodSummary
            } else if hasActivity, let detail = selectedIndex.map({ bars[$0] }) ?? bars.last {
                selectedSummary(detail)
            }
            if compact, hasActivity, activeDays < 3 {
                weekStrip
            } else if hasActivity {
                histogram
            } else {
                ContentUnavailableView {
                    Label(L.t("還沒有學習紀錄", "No activity yet"), systemImage: "chart.bar")
                } description: {
                    Text(L.t("背單字、做測驗或口說練習後，這裡就會出現長條圖。", "Study, take a quiz or practice speaking and your bars appear here."))
                }
                .frame(minHeight: chartHeight)
                .accessibilityIdentifier(compact ? "me-week-chart-empty" : "history-chart-empty")
            }
        }
        .padding(.vertical, 4)
        .onChange(of: selection) { _, value in
            if let value, bars.contains(where: { $0.date == value }) { inspectedDay = value }
        }
        .onChange(of: activity.count) { _, _ in selection = nil; inspectedDay = nil }
        .onChange(of: activity.last?.date) { _, _ in selection = nil; inspectedDay = nil }
        .sensoryFeedback(.selection, trigger: selectedIndex) { _, _ in model.settings.hapticsEnabled ?? true }
    }

    // MARK: Summaries

    private var periodSummary: some View {
        let total = activity.reduce(0) { $0 + $1.total }
        return VStack(alignment: .leading, spacing: 8) {
            Text(L.t("共 \(total) 次", "\(total) actions"))
                .font(.rounded(.title3, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            legend { kind in activity.reduce(0) { $0 + kind.count(in: $1) } }
        }
    }

    private func selectedSummary(_ detail: DailyLearningActivity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title(for: detail))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("history-selected-date")
                Spacer(minLength: 8)
                Text(L.t("\(detail.total) 次", "\(detail.total) actions"))
                    .font(.rounded(.title3, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("history-selected-count")
            }
            legend { $0.count(in: detail) }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: detail)
    }

    /// Colored dots with counts, e.g. "● 單字 9  ● 測驗 3  ● 口說 2".
    private func legend(_ count: @escaping (Kind) -> Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { legendItems(count) }
            VStack(alignment: .leading, spacing: 6) { legendItems(count) }
        }
        .font(.caption)
    }

    private func legendItems(_ count: @escaping (Kind) -> Int) -> some View {
        Group {
            ForEach(Kind.allCases) { kind in
                HStack(spacing: 4) {
                    Circle().fill(kind.color).frame(width: 7, height: 7)
                    Text(kind.label).foregroundStyle(.secondary)
                    Text("\(count(kind))").fontWeight(.semibold).monospacedDigit()
                        .contentTransition(.numericText())
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(kind.label), \(count(kind))")
                .accessibilityIdentifier(compact ? "me-week-\(kind.rawValue)" : "history-selected-\(kind.rawValue)")
            }
        }
    }

    private var activeDays: Int { activity.filter { $0.total > 0 }.count }

    /// A quiet first week: one dot per day instead of a mostly empty chart.
    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(activity) { day in
                let today = day.date == activity.last?.date
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(day.total > 0 ? Palette.accent : Palette.fill)
                        if day.total > 0 {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .overlay {
                        if today { Circle().stroke(Palette.accent, lineWidth: 2).padding(-4) }
                    }
                    Text(axisLabel(day.date))
                        .font(.caption2.weight(today ? .bold : .regular))
                        .foregroundStyle(today ? Palette.accent : Palette.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title(for: day)), \(L.t("\(day.total) 次", "\(day.total) actions"))")
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("me-week-strip")
    }

    // MARK: Chart

    private var histogram: some View {
        let selectedDate = selectedIndex.map { bars[$0].date }
        let chart = Chart {
            ForEach(segments) { segment in
                BarMark(x: .value("Day", segment.day.date), y: .value("Actions", segment.count),
                        width: .ratio(bars.count <= 14 ? 0.6 : 0.8), stacking: .standard)
                    .foregroundStyle(by: .value("Practice", segment.kind.rawValue))
                    .opacity(selectedDate == nil || selectedDate == segment.day.date ? 1 : 0.35)
                    .accessibilityLabel("\(title(for: segment.day)), \(segment.kind.label)")
                    .accessibilityValue("\(segment.count)")
            }
            if let selectedDate {
                RuleMark(x: .value("Day", selectedDate))
                    .foregroundStyle(Palette.secondaryLabel.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXScale(domain: bars.map(\.date))
        .chartYScale(domain: 0...max(4, bars.map(\.total).max() ?? 0))
        .chartForegroundStyleScale(domain: Kind.allCases.map(\.rawValue), range: Kind.allCases.map(\.color))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: bars.map(\.date)) { value in
                AxisValueLabel(anchor: bars.count > 7 && value.as(String.self) == bars.last?.date ? .topTrailing : .top) {
                    if let date = value.as(String.self) {
                        Text(ticks.contains(date) ? axisLabel(date) : "").font(.caption2).fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                AxisValueLabel()
            }
        }
        .frame(height: chartHeight)
        .accessibilityLabel(L.t("每日學習次數", "Daily learning actions"))
        .accessibilityIdentifier(compact ? "me-week-chart" : "history-chart")
        // Recreate the categorical axis when its date range changes.
        .id(activity.count)

        return Group {
            if compact {
                chart
            } else {
                chart.chartXSelection(value: $selection)
            }
        }
    }

    // MARK: Dates

    /// "今天", "昨天", "10月12日 週日", or a week such as "9/28 – 10/4".
    private func title(for day: DailyLearningActivity) -> String {
        let today = activity.last?.endDate ?? day.endDate
        if day.isRange {
            if day.endDate == today { return L.t("最近 7 天", "Last 7 days") }
            return "\(format(day.date, "M/d")) – \(format(day.endDate, "M/d"))"
        }
        if day.date == today { return L.t("今天", "Today") }
        if day.date == DayMath.addDays(today, -1) { return L.t("昨天", "Yesterday") }
        return format(day.date, L.zh ? "M月d日 EEE" : "EEE, MMM d")
    }

    private func axisLabel(_ key: String) -> String {
        bars.count <= 7 ? format(key, L.zh ? "EEEEE" : "EEE") : format(key, "M/d")
    }

    private func format(_ key: String, _ pattern: String) -> String {
        guard let number = DayMath.dayNumber(key) else { return key }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L.zh ? "zh_Hant_TW" : "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = pattern
        return formatter.string(from: Date(timeIntervalSince1970: Double(number) * 86_400))
    }
}
