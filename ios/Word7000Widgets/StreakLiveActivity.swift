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
                .activityBackgroundTint(Color(red: 0.063, green: 0.071, blue: 0.09))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: context.attributes.url ?? "word7000://study"))
        } dynamicIsland: { context in
            let props = Props(context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: props.symbol).foregroundStyle(props.accent)
                        Text(props.badge).font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .font(.system(size: 19))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Metric(props: props, size: 19)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(props.value.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(props.value.keepStreakLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        ProgressLine(props: props)
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: props.symbol).font(.system(size: 15)).foregroundStyle(props.accent)
                    Text(props.badge).font(.system(size: 12, weight: .bold, design: .rounded))
                }
            } compactTrailing: {
                Metric(props: props, size: 13, showLabel: false)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: props.symbol).foregroundStyle(props.accent)
            }
            .widgetURL(URL(string: context.attributes.url ?? "word7000://study"))
            .keylineTint(props.accent)
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
    var completed: Bool { value.isNoon && current >= target }

    var accent: Color {
        if !value.isNoon { return Color(red: 1, green: 0.624, blue: 0.039) }
        return completed ? Color(red: 0.188, green: 0.82, blue: 0.345) : Color(red: 0.251, green: 0.663, blue: 1)
    }

    var symbol: String {
        if !value.isNoon { return "flame.fill" }
        return completed ? "checkmark.circle.fill" : "book.closed.fill"
    }

    var badge: String { value.isNoon ? "W7" : "\(value.streak)" }
}

struct Metric: View {
    var props: Props
    var size: CGFloat
    var showLabel = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if props.value.isNoon {
                Text("\(Int(props.current))/\(Int(props.target))")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(timerInterval: props.value.startDate...props.value.endDate, countsDown: true)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(props.accent)
            }
            if showLabel {
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
        HStack(spacing: 12) {
            Image(systemName: props.symbol)
                .font(.system(size: 21))
                .foregroundStyle(props.accent)
                .frame(width: 42, height: 42)
                .background(props.accent.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(props.value.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(props.value.keepStreakLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ProgressLine(props: props)
                HStack {
                    Text(props.value.streakLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(props.accent)
                    Spacer()
                    Text("Word7000")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Metric(props: props, size: 21)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
    }
}
