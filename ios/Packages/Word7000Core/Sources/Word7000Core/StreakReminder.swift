import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// What the lock screen / Dynamic Island card shows. The server sends the
/// same shape (as a JSON string) when it starts a card by push, so the field
/// names must not change.
public struct StreakActivityProps: Codable, Equatable, Hashable, Sendable {
    /// "streak" (last hour before a streak ends) or "noon" (midday nudge).
    public var activityKind: String?
    public var countdownLabel: String
    /// Milliseconds since 1970.
    public var expiresAt: Double
    public var keepStreakLabel: String
    public var progressCurrent: Double?
    public var progressTarget: Double?
    /// Milliseconds since 1970.
    public var startedAt: Double
    public var streak: Int
    public var streakLabel: String
    public var title: String

    public init(activityKind: String?, countdownLabel: String, expiresAt: Double, keepStreakLabel: String, progressCurrent: Double?, progressTarget: Double?, startedAt: Double, streak: Int, streakLabel: String, title: String) {
        self.activityKind = activityKind
        self.countdownLabel = countdownLabel
        self.expiresAt = expiresAt
        self.keepStreakLabel = keepStreakLabel
        self.progressCurrent = progressCurrent
        self.progressTarget = progressTarget
        self.startedAt = startedAt
        self.streak = streak
        self.streakLabel = streakLabel
        self.title = title
    }

    public var isNoon: Bool { activityKind == "noon" }
    public var startDate: Date { Date(timeIntervalSince1970: startedAt / 1000) }
    public var endDate: Date { Date(timeIntervalSince1970: expiresAt / 1000) }

    public static func decode(_ json: String) -> StreakActivityProps? {
        try? JSONDecoder().decode(StreakActivityProps.self, from: Data(json.utf8))
    }

    public var json: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// The local "your streak needs you" card, in either interface language.
    public static func streak(plan: StreakReminderPlan, chineseInterface: Bool) -> StreakActivityProps? {
        guard let startsAt = plan.startsAt, let expiresAt = plan.expiresAt else { return nil }
        return StreakActivityProps(
            activityKind: "streak",
            countdownLabel: chineseInterface ? "剩餘時間" : "Time left",
            expiresAt: expiresAt.timeIntervalSince1970 * 1000,
            keepStreakLabel: chineseInterface ? "完成 1 個單字即可保住連勝" : "Study 1 word to keep it",
            progressCurrent: 0,
            progressTarget: 1,
            startedAt: startsAt.timeIntervalSince1970 * 1000,
            streak: plan.streak,
            streakLabel: chineseInterface ? "連勝 \(plan.streak) 天" : "\(plan.streak)-day streak",
            title: chineseInterface ? "你的連勝快中斷了" : "Your streak needs you"
        )
    }
}

public struct StreakReminderPlan: Equatable, Sendable {
    public var activeNow: Bool
    public var expiresAt: Date?
    public var startsAt: Date?
    public var streak: Int

    /// A streak ends at the end of the day after the last study day; the
    /// reminder covers its final hour. Ported from `buildStreakReminderPlan`.
    public static func make(progress: ProgressState, now: Date = Date(), enabled: Bool, calendar: Calendar = .current) -> StreakReminderPlan {
        let empty = StreakReminderPlan(activeNow: false, expiresAt: nil, startsAt: nil, streak: max(0, progress.streak))
        guard enabled, progress.streak > 0, let last = progress.lastStudyDate,
              let lastDay = DayMath.dayNumber(last)
        else { return empty }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let parts = utc.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(lastDay) * 86_400))
        guard let lastStart = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day)) else { return empty }
        let todayStart = calendar.startOfDay(for: now)
        let elapsed = calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 99
        guard (0...1).contains(elapsed), let expiresAt = calendar.date(byAdding: .day, value: 2, to: lastStart) else { return empty }
        let startsAt = expiresAt.addingTimeInterval(-3600)
        return StreakReminderPlan(activeNow: startsAt <= now && now < expiresAt, expiresAt: expiresAt, startsAt: startsAt, streak: progress.streak)
    }
}

#if canImport(ActivityKit) && os(iOS)
/// Must keep this exact type name: the server starts cards with
/// `attributes-type: LiveActivityAttributes`.
public struct LiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var name: String
        /// `StreakActivityProps` as a JSON string.
        public var props: String

        public init(name: String = "StreakLiveActivity", props: String) {
            self.name = name
            self.props = props
        }
    }

    public var url: String?

    public init(url: String? = nil) {
        self.url = url
    }
}
#endif
