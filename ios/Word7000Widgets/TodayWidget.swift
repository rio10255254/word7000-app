import SwiftUI
import WidgetKit
import Word7000Core

/// Today's progress, the streak and a word of the day on the home and lock
/// screens. The app writes a small snapshot whenever progress changes; the
/// timeline only adds an entry for each coming midnight so the day turns
/// over without the app.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HomeWidgetStore.kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "word7000://study"))
        }
        .configurationDisplayName("Word7000")
        .description("今天的學習進度、連續天數與每日一字。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    /// The calendar day this entry stands for (YYYY-MM-DD).
    let day: String
    let snapshot: HomeWidgetSnapshot?

    var display: HomeWidgetSnapshot.Display? { snapshot?.display(on: day) }
    var chinese: Bool { snapshot?.chineseInterface ?? true }

    func t(_ zh: String, _ en: String) -> String { chinese ? zh : en }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), day: DayMath.today(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        let stored = HomeWidgetStore().load()
        completion(TodayEntry(date: Date(), day: DayMath.today(), snapshot: stored ?? (context.isPreview ? .sample : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snapshot = HomeWidgetStore().load()
        let calendar = Calendar.current
        let now = Date()
        var entries = [TodayEntry(date: now, day: DayMath.today(now), snapshot: snapshot)]
        var midnight = calendar.startOfDay(for: now)
        for _ in 1..<HomeWidgetSnapshot.daysAhead {
            guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
            entries.append(TodayEntry(date: midnight, day: DayMath.today(midnight), snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

private enum WidgetPalette {
    static let accent = Color(red: 0.145, green: 0.388, blue: 0.922)
    static let known = Color(red: 0.188, green: 0.78, blue: 0.345)
    static let streak = Color(red: 1, green: 0.584, blue: 0)
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodayEntry

    var body: some View {
        if let display = entry.display {
            switch family {
            case .accessoryCircular: circular(display)
            case .accessoryRectangular: rectangular(display)
            case .accessoryInline: inline(display)
            case .systemMedium: medium(display)
            default: small(display)
            }
        } else {
            empty
        }
    }

    private func color(_ display: HomeWidgetSnapshot.Display) -> Color {
        display.goalDone ? WidgetPalette.known : WidgetPalette.accent
    }

    private func goalLine(_ display: HomeWidgetSnapshot.Display) -> String {
        if display.goalDone { return entry.t("今天的目標完成了", "Today's goal is done") }
        let left = display.target - display.studied
        return entry.t("還差 \(left) 個字", "\(left) words to go")
    }

    // MARK: Home screen

    private func small(_ display: HomeWidgetSnapshot.Display) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.t("今天", "Today")).font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                streak(display)
            }
            Spacer(minLength: 0)
            ring(display, size: 74, lineWidth: 9)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Text(goalLine(display))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func medium(_ display: HomeWidgetSnapshot.Display) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.t("今天", "Today")).font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    streak(display)
                }
                Spacer(minLength: 0)
                ring(display, size: 70, lineWidth: 9)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text(goalLine(display))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: 130)
            Divider()
            wordOfTheDay(display.word)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func wordOfTheDay(_ word: HomeWidgetSnapshot.Word?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(entry.t("每日一字", "Word of the day"), systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetPalette.accent)
            if let word {
                Spacer(minLength: 0)
                // Learners of Chinese see the meaning first, like on their cards.
                Text(entry.chinese ? word.word : word.meaning)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if entry.chinese, !word.pronunciation.isEmpty {
                    Text(word.pronunciation).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                }
                Text([word.partOfSpeech, entry.chinese ? word.meaning : word.word].filter { !$0.isEmpty }.joined(separator: "  "))
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                Spacer(minLength: 0)
            } else {
                Spacer()
            }
        }
    }

    private func ring(_ display: HomeWidgetSnapshot.Display, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color(display).opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: display.fraction)
                .stroke(color(display), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(display.studied)")
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/ \(display.target)")
                    .font(.system(size: size * 0.15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func streak(_ display: HomeWidgetSnapshot.Display) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
            Text("\(display.streak)").monospacedDigit()
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(display.streak > 0 ? WidgetPalette.streak : .secondary)
        .accessibilityLabel(entry.t("連續 \(display.streak) 天", "\(display.streak)-day streak"))
    }

    // MARK: Lock screen

    private func circular(_ display: HomeWidgetSnapshot.Display) -> some View {
        Gauge(value: display.fraction) {
            Image(systemName: "book.closed.fill")
        } currentValueLabel: {
            Text("\(display.studied)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    private func rectangular(_ display: HomeWidgetSnapshot.Display) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text(entry.t("連續 \(display.streak) 天", "\(display.streak)-day streak"))
            }
            .font(.system(size: 14, weight: .bold))
            .widgetAccentable()
            Text(entry.t("今天 \(display.studied)/\(display.target) 個", "Today \(display.studied) of \(display.target)"))
                .font(.system(size: 13, weight: .semibold))
            Gauge(value: display.fraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
    }

    private func inline(_ display: HomeWidgetSnapshot.Display) -> some View {
        Label(entry.t("\(display.studied)/\(display.target) · 連續 \(display.streak) 天", "\(display.studied)/\(display.target) · \(display.streak)-day streak"),
              systemImage: "flame.fill")
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(WidgetPalette.accent)
            Text(entry.t("打開 Word7000 開始今天的學習", "Open Word7000 to start today"))
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
        }
    }
}

extension HomeWidgetSnapshot {
    /// Shown in the widget gallery before the app has written anything.
    static var sample: HomeWidgetSnapshot {
        let today = DayMath.today()
        var words: [String: Word] = [:]
        for offset in 0..<daysAhead {
            if let day = DayMath.addDays(today, offset) {
                words[day] = Word(word: "abandon", pronunciation: "/əˈbændən/", meaning: "遺棄", partOfSpeech: "vt")
            }
        }
        return HomeWidgetSnapshot(date: today, studiedToday: 12, dailyTarget: 20, streak: 5, lastStudyDate: today,
                                  streakFreezeDate: nil, chineseInterface: true, words: words)
    }
}
