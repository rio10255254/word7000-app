import ActivityKit
import SwiftUI
import WidgetKit
import Word7000Core

/// The lock screen and Dynamic Island card: the midday study nudge (today's
/// progress) or the last hour before a streak ends (a countdown). Laid out
/// like a note from the cat: the app's name, one plain sentence, the cat, and
/// one thick bar with the count. Cards can be started by the app or by the
/// server through a push; both send the same `StreakActivityProps`, so the
/// look can change without either of them.
struct StreakLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            LockScreenCard(props: Props(context.state))
                .activityBackgroundTint(LiveColors.background)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: context.attributes.url ?? "word7000://study"))
        } dynamicIsland: { context in
            let props = Props(context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveCat(size: 52)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StreakChip(props: props)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(props.appName)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(props.message)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressPill(props: props, height: 18)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
            } compactLeading: {
                LiveCat(size: 24)
            } compactTrailing: {
                CompactCount(props: props)
            } minimal: {
                MinimalRing(props: props)
            }
            .widgetURL(URL(string: context.attributes.url ?? "word7000://study"))
            .keylineTint(props.accent)
        }
    }
}

enum LiveColors {
    // The olive of the app icon, deep enough for white text, with a warm
    // mustard bar like a highlighter; green once the goal is done.
    static let background = Color(red: 0.15, green: 0.18, blue: 0.11)
    static let backgroundTop = Color(red: 0.31, green: 0.36, blue: 0.22)
    static let track = Color.white.opacity(0.14)
    static let mustard = Color(red: 0.93, green: 0.73, blue: 0.29)
    static let clay = Color(red: 0.93, green: 0.55, blue: 0.40)
    static let green = Color(red: 0.70, green: 0.84, blue: 0.53)
    /// Text on a filled bar.
    static let ink = Color(red: 0.13, green: 0.15, blue: 0.09)
}

/// Decoded props, and what the card says about them.
struct Props {
    var value: StreakActivityProps

    init(_ state: LiveActivityAttributes.ContentState) {
        value = StreakActivityProps.decode(state.props) ?? StreakActivityProps(
            activityKind: "streak", countdownLabel: "", expiresAt: Date().timeIntervalSince1970 * 1000, keepStreakLabel: "",
            progressCurrent: nil, progressTarget: nil, startedAt: Date().timeIntervalSince1970 * 1000, streak: 0, streakLabel: "", title: "單字貓"
        )
    }

    var target: Double { max(1, value.progressTarget ?? 1) }
    /// The app writes the card in the interface language, so a title in
    /// Chinese means a Chinese card.
    var chinese: Bool { value.title.unicodeScalars.contains { $0.properties.isIdeographic } }
    var appName: String { chinese ? "單字貓" : "WordCat" }
    var current: Double { min(max(0, value.progressCurrent ?? 0), target) }
    var fraction: Double { current / target }
    /// Today's goal reached (noon card) or the streak kept (last-hour card).
    /// The app shows this for a few minutes before the card goes away.
    var finished: Bool { current >= target }

    /// One plain sentence: what is left to do, or that it is done.
    var message: String {
        if finished { return value.title }
        return value.keepStreakLabel.isEmpty ? value.title : value.keepStreakLabel
    }

    var accent: Color {
        if finished { return LiveColors.green }
        return value.isNoon ? LiveColors.mustard : LiveColors.clay
    }
}

/// The cat, as on the app icon.
struct LiveCat: View {
    var size: CGFloat

    var body: some View {
        Image("LiveCat")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The streak, small: a flame and the days.
struct StreakChip: View {
    var props: Props

    var body: some View {
        if props.value.streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(props.value.isNoon ? LiveColors.clay : props.accent)
                Text("\(props.value.streak)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(props.value.streak)))
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(props.value.streakLabel)
        }
    }
}

/// One thick bar: today's words with the count in it, or the time left.
struct ProgressPill: View {
    var props: Props
    var height: CGFloat = 22

    var body: some View {
        if props.value.isNoon || props.finished {
            GeometryReader { proxy in
                let filled = max(height, proxy.size.width * props.fraction)
                ZStack(alignment: .leading) {
                    Capsule().fill(LiveColors.track)
                    Capsule().fill(props.accent).frame(width: props.fraction > 0 ? filled : 0)
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        if props.finished { Image(systemName: "checkmark") }
                        Text("\(Int(props.current)) / \(Int(props.target))")
                            .monospacedDigit()
                            .contentTransition(.numericText(value: props.current))
                    }
                    .font(.system(size: height * 0.62, weight: .bold, design: .rounded))
                    // On the bar once it reaches the count, beside it before.
                    .foregroundStyle(props.fraction > 0.78 ? LiveColors.ink : .white)
                    .padding(.horizontal, height * 0.5)
                }
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(props.current)) / \(Int(props.target))")
        } else {
            HStack(spacing: 10) {
                // The time left, running down on its own.
                ProgressView(timerInterval: props.value.startDate...props.value.endDate, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(props.accent)
                .scaleEffect(x: 1, y: height / 8, anchor: .center)
                .clipShape(Capsule())
                Text(timerInterval: props.value.startDate...props.value.endDate, countsDown: true)
                    .font(.system(size: height * 0.68, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(props.accent)
                    .frame(width: height * 3.2, alignment: .trailing)
            }
            .frame(height: height)
        }
    }
}

/// The Dynamic Island's right side: the count, or the time left.
struct CompactCount: View {
    var props: Props

    var body: some View {
        Group {
            if props.finished {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
            } else if props.value.isNoon {
                Text("\(Int(props.current))/\(Int(props.target))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: props.current))
            } else {
                Text(timerInterval: props.value.startDate...props.value.endDate, countsDown: true)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 46)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(props.accent)
    }
}

/// The smallest Dynamic Island: a ring filling up with today's words, or a
/// flame for the last hour of a streak.
struct MinimalRing: View {
    var props: Props

    var body: some View {
        if props.value.isNoon || props.finished {
            ZStack {
                Circle().stroke(LiveColors.track, lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: props.fraction)
                    .stroke(props.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                LiveCat(size: 14)
            }
            .frame(width: 22, height: 22)
        } else {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(props.accent)
        }
    }
}

/// The lock screen card: the app's name, one sentence and the cat on top,
/// one thick bar underneath.
struct LockScreenCard: View {
    var props: Props

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(props.appName)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                        StreakChip(props: props)
                    }
                    Text(props.message)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                LiveCat(size: 72)
                    .padding(.top, -4)
            }
            ProgressPill(props: props)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [LiveColors.backgroundTop, LiveColors.background], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}
