import Charts
import SwiftUI
import Word7000Core

struct HistoryActivityChart: View {
    var counts: [Int]
    var endDate: String
    var dailyTarget: Int
    @State private var selection: Int?
    @State private var inspectedDay: Int?

    private struct Day: Identifiable {
        var id: Int
        var key: String
        var count: Int
    }

    private var days: [Day] {
        counts.enumerated().map { index, count in
            Day(id: index, key: DayMath.addDays(endDate, index - counts.count + 1) ?? endDate, count: count)
        }
    }

    private var selectedDay: Day? {
        guard let index = inspectedDay ?? selection, days.indices.contains(index) else { return nil }
        return days[index]
    }

    private var ticks: [Int] {
        Array(Array(stride(from: max(0, counts.count - 1), through: 0, by: counts.count > 30 ? -21 : -7)).reversed())
    }

    var body: some View {
        let values = days
        let detail = selectedDay ?? values.last
        VStack(alignment: .leading, spacing: 14) {
            if counts.contains(where: { $0 > 0 }) {
                HStack(alignment: .firstTextBaseline) {
                    Text(detail?.key ?? endDate)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("history-selected-date")
                    Spacer(minLength: 8)
                    Text(L.t("\(detail?.count ?? 0) 次", "\(detail?.count ?? 0) actions"))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("history-selected-count")
                }
                Chart {
                    ForEach(values) { day in
                        AreaMark(x: .value("Day", day.id), y: .value("Actions", day.count))
                            .foregroundStyle(LinearGradient(colors: [Palette.accent.opacity(0.18), Palette.accent.opacity(0.02)],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", day.id), y: .value("Actions", day.count))
                            .foregroundStyle(Palette.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    RuleMark(y: .value("Current goal", dailyTarget))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    if let day = selectedDay {
                        RuleMark(x: .value("Day", day.id))
                            .foregroundStyle(Palette.accent.opacity(0.3))
                        PointMark(x: .value("Day", day.id), y: .value("Actions", day.count))
                            .foregroundStyle(Palette.accent)
                            .symbolSize(65)
                    }
                }
                .chartXScale(domain: 0...max(1, values.count - 1))
                .chartYScale(domain: 0...max(max(1, dailyTarget), counts.max() ?? 0))
                .chartXSelection(value: $selection)
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: ticks) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self), values.indices.contains(index) {
                                Text(dateLabel(values[index].key)).font(.caption2)
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
                .frame(height: 180)
                .accessibilityLabel(L.t("每日學習次數", "Daily learning actions"))
                .accessibilityIdentifier("history-chart")
                Text(L.t("目前每日目標 \(dailyTarget) 次", "Current daily goal: \(dailyTarget) actions"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(L.t("這段期間尚無學習紀錄", "No learning activity in this period"),
                                       systemImage: "chart.xyaxis.line")
                    .accessibilityIdentifier("history-chart-empty")
            }
        }
        .padding(.vertical, 4)
        .onChange(of: selection) { _, value in
            if let value, counts.indices.contains(value) { inspectedDay = value }
        }
        .onChange(of: counts.count) { _, _ in selection = nil; inspectedDay = nil }
        .onChange(of: endDate) { _, _ in selection = nil; inspectedDay = nil }
        .sensoryFeedback(.selection, trigger: selectedDay?.id)
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
