import Foundation

/// Usage statistics kept on the iPhone until they are sent: how many times
/// each feature was used per day. Only event names and short details
/// ("speaking", "completed"), never words, answers or recordings.
public struct UsageCounter: Codable, Equatable, Sendable {
    public struct Key: Codable, Hashable, Sendable {
        public var day: String
        public var event: String
        public var detail: String
    }

    public private(set) var counts: [Key: Int] = [:]
    /// Enough for weeks offline; past it new kinds of rows are dropped.
    public static let maxRows = 300

    public init() {}

    public var isEmpty: Bool { counts.isEmpty }

    public static func clean(event: String) -> String? {
        let value = String(event.lowercased().filter { $0.isLetter && $0.isASCII || $0 == "_" }.prefix(32))
        return value.count >= 2 ? value : nil
    }

    public static func clean(detail: String) -> String {
        String(detail.filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || "_.:,-".contains($0) }.prefix(60))
    }

    public static func day(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    public mutating func add(_ event: String, detail: String = "", count: Int = 1, at date: Date = Date()) {
        guard count > 0, let event = Self.clean(event: event) else { return }
        let key = Key(day: Self.day(date), event: event, detail: Self.clean(detail: detail))
        guard counts[key] != nil || counts.count < Self.maxRows else { return }
        counts[key, default: 0] += count
    }

    /// Puts back a batch that could not be sent.
    public mutating func merge(_ other: UsageCounter) {
        for (key, value) in other.counts where counts[key] != nil || counts.count < Self.maxRows {
            counts[key, default: 0] += value
        }
    }

    /// Everything counted so far, for sending, and an empty counter.
    public mutating func drain() -> UsageCounter {
        defer { counts = [:] }
        return self
    }

    /// The batch as the server's log_usage expects it.
    public var rows: [JSONValue] {
        counts.sorted { ($0.key.day, $0.key.event, $0.key.detail) < ($1.key.day, $1.key.event, $1.key.detail) }.map { key, value in
            .object(["day": .string(key.day), "event": .string(key.event), "detail": .string(key.detail), "count": .number(Double(value))])
        }
    }
}
