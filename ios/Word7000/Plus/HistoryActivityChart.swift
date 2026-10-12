import Charts
import SwiftUI
import Word7000Core

struct HistoryActivityChart: View {
    var activity: [DailyLearningActivity]
    var chartHeight: CGFloat = 180
    @State private var selection: String?
    @State private var inspectedDay: String?

    private enum Kind: String, CaseIterable, Identifiable {
        case words, speaking, other
        var id: Self { self }
        var label: String {
            switch self {
            case .words: L.t("單字", "Words")
            case .speaking: L.t("口說", "Speaking")
            case .other: L.t("其他", "Other")
            }
        }
        var color: Color {
            switch self {
            case .words: Palette.accent
            case .speaking: Palette.known
            case .other: Palette.review
            }
        }
        func count(in day: DailyLearningActivity) -> Int {
            switch self {
            case .words: day.words
            case .speaking: day.speaking
            case .other: day.other
            }
        }
    }

    private struct Segment: Identifiable {
        var day: DailyLearningActivity
        var kind: Kind
        var id: String { "\(day.date)-\(kind.rawValue)" }
        var count: Int { kind.count(in: day) }
    }

    private var segments: [Segment] {
        activity.flatMap { day in
            Kind.allCases.map { Segment(day: day, kind: $0) }
        }
    }

    private var selectedIndex: Int? {
        guard let date = inspectedDay ?? selection else { return nil }
        return activity.firstIndex { $0.date == date }
    }

    private var ticks: [String] {
        if activity.count <= 7 { return activity.map(\.date) }
        return stride(from: activity.count - 1, through: 0, by: activity.count > 30 ? -21 : -7)
            .reversed().map { activity[$0].date }
    }

    var body: some View {
        let detail = selectedIndex.map { activity[$0] } ?? activity.last
        VStack(alignment: .leading, spacing: 14) {
            if let detail {
                selectedSummary(detail)
            }
            if activity.contains(where: { $0.total > 0 }) {
                histogram
            } else {
                ContentUnavailableView(L.t("這段期間尚無學習紀錄", "No learning activity in this period"),
                                       systemImage: "chart.bar.xaxis")
                    .frame(minHeight: chartHeight)
                    .accessibilityIdentifier("history-chart-empty")
            }
        }
        .padding(.vertical, 4)
        .onChange(of: selection) { _, value in
            if let value, activity.contains(where: { $0.date == value }) { inspectedDay = value }
        }
        .onChange(of: activity.count) { _, _ in selection = nil; inspectedDay = nil }
        .onChange(of: activity.last?.date) { _, _ in selection = nil; inspectedDay = nil }
        .sensoryFeedback(.selection, trigger: selectedIndex)
    }

    private func selectedSummary(_ detail: DailyLearningActivity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(detail.date)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("history-selected-date")
                Spacer(minLength: 8)
                Text(L.t("\(detail.total) 次", "\(detail.total) actions"))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("history-selected-count")
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Kind.allCases) { kind in breakdown(kind, day: detail) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Kind.allCases) { kind in breakdown(kind, day: detail) }
                }
            }
        }
    }

    private var histogram: some View {
        let selectedDate = selectedIndex.map { activity[$0].date }
        return Chart {
            ForEach(segments) { segment in
                BarMark(x: .value("Day", segment.day.date), y: .value("Actions", segment.count),
                        width: .ratio(activity.count <= 7 ? 0.65 : 0.85), stacking: .standard)
                    .foregroundStyle(by: .value("Practice", segment.kind.rawValue))
                    .opacity(selectedDate == nil || selectedDate == segment.day.date ? 1 : 0.4)
                    .accessibilityLabel("\(segment.day.date), \(segment.kind.label)")
                    .accessibilityValue("\(segment.count)")
            }
            if let selectedDate {
                RuleMark(x: .value("Day", selectedDate))
                    .foregroundStyle(Palette.accent.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXScale(domain: activity.map(\.date))
        .chartYScale(domain: 0...max(1, activity.map(\.total).max() ?? 0))
        .chartForegroundStyleScale(domain: Kind.allCases.map(\.rawValue), range: Kind.allCases.map(\.color))
        .chartXSelection(value: $selection)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                AxisValueLabel(anchor: activity.count > 7 && value.as(String.self) == activity.last?.date ? .topTrailing : .top) {
                    if let date = value.as(String.self) {
                        Text(dateLabel(date)).font(.caption2).fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: chartHeight)
        .accessibilityLabel(L.t("每日學習次數", "Daily learning actions"))
        .accessibilityIdentifier("history-chart")
    }

    private func breakdown(_ kind: Kind, day: DailyLearningActivity) -> some View {
        let count = kind.count(in: day)
        let percent = day.total > 0 ? Int((Double(count) / Double(day.total) * 100).rounded()) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(kind.color).frame(width: 7, height: 7)
                Text(kind.label).foregroundStyle(.secondary)
            }
            .fixedSize()
            Text("\(count) · \(percent)%")
                .fontWeight(.semibold)
                .monospacedDigit()
                .fixedSize()
                .contentTransition(.numericText())
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.label), \(count), \(percent)%")
        .accessibilityIdentifier("history-selected-\(kind.rawValue)")
    }

    private func dateLabel(_ key: String) -> String {
        guard let number = DayMath.dayNumber(key) else { return key }
        return Self.labelFormatter.string(from: Date(timeIntervalSince1970: Double(number) * 86_400))
    }

    private static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
