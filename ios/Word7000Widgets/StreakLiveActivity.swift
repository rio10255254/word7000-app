import ActivityKit
import SwiftUI
import WidgetKit
import Word7000Core

/// The lock screen and Dynamic Island card: the last hour before a streak
/// ends (countdown), or the midday study nudge (today's progress). Cards can
/// be started by the app or by the server through a push.
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
                    Badge(props: props, size: 46)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Metric(props: props, size: 22)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(props.value.title)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(props.value.streakLabel)
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundStyle(props.accent)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(props.value.keepStreakLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if !props.finished { ProgressLine(props: props) }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Badge(props: props, size: 22, compact: true)
            } compactTrailing: {
                Metric(props: props, size: 14, showLabel: false)
                    .frame(maxWidth: 56)
            } minimal: {
                Badge(props: props, size: 22, compact: true, minimal: true)
            }
            .widgetURL(URL(string: context.attributes.url ?? "word7000://study"))
            .keylineTint(props.accent)
        }
    }
}

enum LiveColors {
    // Warm leather browns with terracotta, sage and ochre, bright enough to
    // read on the dark card.
    static let background = Color(red: 0.13, green: 0.1, blue: 0.08)
    static let backgroundTop = Color(red: 0.3, green: 0.2, blue: 0.13)
    static let clay = Color(red: 0.89, green: 0.52, blue: 0.38)
    static let green = Color(red: 0.62, green: 0.76, blue: 0.53)
    static let orange = Color(red: 0.9, green: 0.67, blue: 0.3)
}

/// The left-hand mark: a progress ring around a book for the study nudge, a
/// flame with the streak for the last-hour card, a check once either is done.
struct Badge: View {
    var props: Props
    var size: CGFloat
    var compact = false
    var minimal = false

    var body: some View {
        if props.value.isNoon || props.finished {
            ZStack {
                Circle().stroke(props.accent.opacity(0.25), lineWidth: compact ? 2.5 : 4)
                Circle()
                    .trim(from: 0, to: props.fraction)
                    .stroke(props.accent, style: StrokeStyle(lineWidth: compact ? 2.5 : 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: props.finished ? "checkmark" : "book.closed.fill")
                    .font(.system(size: size * (compact ? 0.42 : 0.38), weight: .bold))
                    .foregroundStyle(props.accent)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
        } else if minimal || compact {
            HStack(spacing: 2) {
                Image(systemName: "flame.fill").foregroundStyle(props.accent)
                if !minimal {
                    Text("\(props.value.streak)")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(props.value.streak)))
                }
            }
            .font(.system(size: 14))
        } else {
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.46))
                    .foregroundStyle(props.accent)
                Text("\(props.value.streak)")
                    .font(.system(size: size * 0.3, weight: .heavy, design: .serif))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(props.value.streak)))
            }
            .frame(width: size, height: size)
        }
    }
}

/// Decoded props plus the colours and symbol for their kind.
struct Props {
    var value: StreakActivityProps

    init(_ state: LiveActivityAttributes.ContentState) {
        value = StreakActivityProps.decode(state.props) ?? StreakActivityProps(
            activityKind: "streak", countdownLabel: "", expiresAt: Date().timeIntervalSince1970 * 1000, keepStreakLabel: "",
            progressCurrent: nil, progressTarget: nil, startedAt: Date().timeIntervalSince1970 * 1000, streak: 0, streakLabel: "", title: "Word7000"
        )
    }

    var target: Double { max(1, value.progressTarget ?? 1) }
    var current: Double { min(max(0, value.progressCurrent ?? 0), target) }
    var fraction: Double { current / target }
    /// Today's goal reached (noon card) or the streak kept (last-hour card).
    /// The app shows this for a few minutes before the card goes away.
    var finished: Bool { current >= target }

    var accent: Color {
        if finished { return LiveColors.green }
        return value.isNoon ? LiveColors.clay : LiveColors.orange
    }
}

struct Metric: View {
    var props: Props
    var size: CGFloat
    var showLabel = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if props.finished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size))
                    .foregroundStyle(props.accent)
                    .transition(.scale.combined(with: .opacity))
            } else if props.value.isNoon {
                Text("\(Int(props.current))/\(Int(props.target))")
                    .font(.system(size: size, weight: .bold, design: .serif))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: props.current))
            } else {
                Text(timerInterval: props.value.startDate...props.value.endDate, countsDown: true)
                    .font(.system(size: size, weight: .bold, design: .serif))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(props.accent)
            }
            if showLabel, !props.finished {
                Text(props.value.countdownLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(props.value.isNoon ? .secondary : props.accent)
            }
        }
    }
}

struct ProgressLine: View {
    var props: Props

    var body: some View {
        if props.value.isNoon {
            ProgressView(value: props.current, total: props.target).tint(props.accent)
        } else {
            ProgressView(timerInterval: props.value.startDate...props.value.endDate, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(props.accent)
        }
    }
}

struct LockScreenCard: View {
    var props: Props

    var body: some View {
        HStack(spacing: 14) {
            Badge(props: props, size: 50)
            VStack(alignment: .leading, spacing: 5) {
                Text(props.value.title)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(props.value.keepStreakLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                if !props.finished { ProgressLine(props: props) }
                HStack {
                    Text(props.value.streakLabel)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundStyle(props.accent)
                    Spacer()
                    Text("Word7000")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Metric(props: props, size: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [LiveColors.backgroundTop, LiveColors.background], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}
