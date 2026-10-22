import ActivityKit
import Foundation
import Word7000Core

/// The lock screen / Dynamic Island card. The app starts the "last hour of
/// your streak" card itself while it runs; the server starts the noon nudge
/// and the streak card by push using this iPhone's push-to-start token.
@MainActor
final class LiveActivityManager {
    private(set) var pushToStartToken: String?

    /// Starts, updates or ends the local streak card to match the plan.
    func sync(plan: StreakReminderPlan, progress: ProgressState, chineseInterface: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let running = ActivityKit.Activity<LiveActivityAttributes>.activities
        for activity in running {
            guard var props = StreakActivityProps.decode(activity.content.state.props), props.isNoon else { continue }
            if props.endDate <= Date() || progress.studiedToday >= progress.dailyTarget {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                props.progressCurrent = Double(progress.studiedToday)
                props.progressTarget = Double(progress.dailyTarget)
                let remaining = max(0, progress.dailyTarget - progress.studiedToday)
                props.keepStreakLabel = chineseInterface ? "再學 \(remaining) 個單字，完成今天目標" : "\(remaining) more words to reach your goal"
                props.title = chineseInterface ? "今天的學習時間" : "Time for today's practice"
                props.countdownLabel = chineseInterface ? "今日進度" : "Today's progress"
                await activity.update(ActivityContent(state: LiveActivityAttributes.ContentState(props: props.json), staleDate: props.endDate))
            }
        }
        guard plan.activeNow, let props = StreakActivityProps.streak(plan: plan, chineseInterface: chineseInterface),
              let expiresAt = plan.expiresAt, Date() < expiresAt
        else {
            for activity in running where StreakActivityProps.decode(activity.content.state.props)?.isNoon != true {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        let content = ActivityContent(state: LiveActivityAttributes.ContentState(props: props.json), staleDate: expiresAt)
        if let first = running.first(where: { StreakActivityProps.decode($0.content.state.props)?.isNoon != true }) {
            await first.update(content)
        } else {
            _ = try? ActivityKit.Activity<LiveActivityAttributes>.request(attributes: LiveActivityAttributes(url: "word7000://study"), content: content, pushType: .token)
        }
    }

    /// Ends every card, e.g. when reminders are turned off.
    func endAll() async {
        for activity in ActivityKit.Activity<LiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Calls `onChange` with each new push-to-start token (iOS 17.2+).
    func observePushToStartTokens(_ onChange: @escaping @MainActor (String) -> Void) async {
        guard #available(iOS 17.2, *) else { return }
        if let token = ActivityKit.Activity<LiveActivityAttributes>.pushToStartToken {
            let hex = token.map { String(format: "%02x", $0) }.joined()
            pushToStartToken = hex
            onChange(hex)
        }
        for await token in ActivityKit.Activity<LiveActivityAttributes>.pushToStartTokenUpdates {
            let hex = token.map { String(format: "%02x", $0) }.joined()
            pushToStartToken = hex
            onChange(hex)
        }
    }

    /// The row the server needs to start cards on this iPhone at the right
    /// time. The upload coordinator owns deduplication and acknowledgments.
    func registration(deviceId: String, plan: StreakReminderPlan, enabled: Bool, progress: ProgressState, chineseInterface: Bool, today: String, reminderMinute: Int? = nil) -> [String: JSONValue]? {
        guard let token = pushToStartToken else { return nil }
        let iso = ISO8601DateFormatter()
        var row: [String: JSONValue] = [
            "device_id": .string(deviceId),
            "push_to_start_token": .string(token),
            "enabled": .bool(enabled),
            "app_locale": .string(chineseInterface ? "zh-TW" : "en"),
            "time_zone": .string(TimeZone.current.identifier),
            "streak": .number(Double(plan.streak)),
            "streak_expires_at": plan.expiresAt.map { .string(iso.string(from: $0)) } ?? .null,
            "daily_target": .number(Double(max(1, progress.dailyTarget))),
            "studied_today": .number(Double(max(0, progress.studiedToday))),
            "progress_date": .string(today),
        ]
        if let reminderMinute { row["reminder_minute"] = .number(Double(min(1439, max(0, reminderMinute)))) }
        return row
    }
}
