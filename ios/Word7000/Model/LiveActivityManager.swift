import ActivityKit
import Foundation
import Word7000Core

/// The lock screen / Dynamic Island card. The app starts the "last hour of
/// your streak" card itself while it runs; the server starts the noon nudge
/// and the streak card by push using this iPhone's push-to-start token.
@MainActor
final class LiveActivityManager {
    private(set) var pushToStartToken: String?
    /// How long a "done" card stays before it goes away on its own.
    static let celebrationTime: TimeInterval = 8 * 60

    /// Starts, updates or ends the local streak card to match the plan.
    func sync(plan: StreakReminderPlan, progress: ProgressState, chineseInterface: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let running = ActivityKit.Activity<LiveActivityAttributes>.activities
        for activity in running {
            guard var props = StreakActivityProps.decode(activity.content.state.props), props.isNoon else { continue }
            if props.endDate <= Date() {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else if progress.studiedToday >= progress.dailyTarget {
                // Show the goal as done for a few minutes rather than vanishing.
                guard (props.progressCurrent ?? 0) < (props.progressTarget ?? 1) else { continue }
                props.progressCurrent = Double(progress.dailyTarget)
                props.progressTarget = Double(progress.dailyTarget)
                props.title = chineseInterface ? "今天的目標完成了" : "Today's goal is done"
                props.keepStreakLabel = chineseInterface ? "學了 \(progress.studiedToday) 個單字，明天見！" : "\(progress.studiedToday) words today. See you tomorrow!"
                props.streakLabel = chineseInterface ? "連續 \(max(1, progress.streak)) 天" : "\(max(1, progress.streak))-day streak"
                await activity.end(ActivityContent(state: LiveActivityAttributes.ContentState(props: props.json), staleDate: nil),
                                   dismissalPolicy: .after(Date().addingTimeInterval(Self.celebrationTime)))
            } else {
                props.progressCurrent = Double(progress.studiedToday)
                props.progressTarget = Double(progress.dailyTarget)
                let remaining = max(0, progress.dailyTarget - progress.studiedToday)
                props.keepStreakLabel = chineseInterface ? "再學 \(remaining) 個單字，完成今天目標" : "\(remaining) more words to reach your goal"
                props.title = chineseInterface ? "單字不會自己背好喔" : "Those words won't learn themselves"
                props.countdownLabel = chineseInterface ? "今日進度" : "Today's progress"
                await activity.update(ActivityContent(state: LiveActivityAttributes.ContentState(props: props.json), staleDate: props.endDate))
            }
        }
        guard plan.activeNow, let props = StreakActivityProps.streak(plan: plan, chineseInterface: chineseInterface),
              let expiresAt = plan.expiresAt, Date() < expiresAt
        else {
            // Studying today in the last hour saves the streak: say so briefly.
            let saved = progress.lastStudyDate == DayMath.today() && progress.streak > 0
            for activity in running {
                guard var props = StreakActivityProps.decode(activity.content.state.props), !props.isNoon else { continue }
                if saved, props.endDate > Date(), (props.progressCurrent ?? 0) < (props.progressTarget ?? 1) {
                    props.progressCurrent = 1
                    props.progressTarget = 1
                    props.streak = progress.streak
                    props.title = chineseInterface ? "連勝保住了！" : "Streak saved!"
                    props.keepStreakLabel = chineseInterface ? "今天也學了，繼續保持" : "You studied today. Keep it going"
                    props.streakLabel = chineseInterface ? "連續 \(progress.streak) 天" : "\(progress.streak)-day streak"
                    await activity.end(ActivityContent(state: LiveActivityAttributes.ContentState(props: props.json), staleDate: nil),
                                       dismissalPolicy: .after(Date().addingTimeInterval(Self.celebrationTime)))
                } else if !saved || props.endDate <= Date() {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            return
        }
        let content = ActivityContent(state: LiveActivityAttributes.ContentState(props: props.json), staleDate: expiresAt)
        if let first = running.first(where: { $0.activityState == .active && StreakActivityProps.decode($0.content.state.props)?.isNoon != true }) {
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
