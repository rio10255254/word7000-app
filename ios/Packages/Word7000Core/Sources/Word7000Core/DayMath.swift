import Foundation

/// Calendar days as `YYYY-MM-DD` strings, the format the app has always
/// stored. Arithmetic runs on whole UTC days so a date never shifts with the
/// device's time zone.
public enum DayMath {
    private static let secondsPerDay = 86_400

    public static func dayNumber(_ value: String) -> Int? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), day >= 1
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return Int((date.timeIntervalSince1970 / Double(secondsPerDay)).rounded(.down))
    }

    public static func string(fromDayNumber number: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(number * secondsPerDay))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    public static func addDays(_ date: String, _ days: Int) -> String? {
        guard let number = dayNumber(date) else { return nil }
        return string(fromDayNumber: number + days)
    }

    public static func isPreviousDay(_ previous: String, of today: String) -> Bool {
        guard let previous = dayNumber(previous), let current = dayNumber(today) else { return false }
        return current - previous == 1
    }

    /// Today in the learner's own time zone, which is what "today" means for
    /// a daily goal and a streak.
    public static func today(_ now: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// ISO 8601 with milliseconds, like JavaScript's `toISOString()`, so
    /// timestamps compare as strings across both apps.
    public static func timestamp(_ date: Date = Date()) -> String {
        timestampFormatter.string(from: date)
    }

    nonisolated(unsafe) private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
