import Foundation

/// What Word7000 Plus unlocks, and the free trial before it.
///
/// Studying the 7000 words, reviews, quizzes, speaking practice and the last
/// seven days of stats are always free. Everyone gets every Plus feature for
/// seven days from first launch, with scanning capped so the trial cannot be
/// used to scan a whole book; after that the Plus features need a
/// subscription.
public enum PlusFeature: String, CaseIterable, Sendable {
    /// Scanning word lists, handwriting and on-device AI tidying.
    case scan
    /// Uploading progress to the cloud (local data is never touched).
    case sync
    /// Learning history beyond the last seven days.
    case history
    /// Timed mock exams.
    case examPractice
}

public enum PlusAccess: Equatable, Sendable {
    case subscribed
    case trial(daysLeft: Int)
    case expired

    public var isActive: Bool { self != .expired }
}

public struct PlusPolicy: Sendable {
    public static let trialDays = 7
    public static let trialScanLimit = 5
    public static let freeHistoryDays = 7

    public var trialStartedAt: Date
    public var subscribed: Bool
    public var trialScansUsed: Int

    public init(trialStartedAt: Date, subscribed: Bool, trialScansUsed: Int) {
        self.trialStartedAt = trialStartedAt
        self.subscribed = subscribed
        self.trialScansUsed = trialScansUsed
    }

    public var trialEndsAt: Date { trialStartedAt.addingTimeInterval(Double(Self.trialDays) * 86_400) }

    public func access(now: Date = Date()) -> PlusAccess {
        if subscribed { return .subscribed }
        guard now < trialEndsAt else { return .expired }
        let left = Int((trialEndsAt.timeIntervalSince(now) / 86_400).rounded(.up))
        return .trial(daysLeft: max(1, left))
    }

    public enum Decision: Equatable, Sendable {
        case allowed
        /// The trial ended (or never applied); a subscription unlocks it.
        case needsPlus
        /// Still in the trial, but its scan allowance is used up.
        case trialLimitReached
    }

    public func decide(_ feature: PlusFeature, now: Date = Date()) -> Decision {
        switch access(now: now) {
        case .subscribed:
            return .allowed
        case .expired:
            return .needsPlus
        case .trial:
            if feature == .scan, trialScansUsed >= Self.trialScanLimit { return .trialLimitReached }
            return .allowed
        }
    }

    public var trialScansLeft: Int { max(0, Self.trialScanLimit - trialScansUsed) }

    /// The earliest of the trial starts recorded on this iPhone and in the
    /// account, so neither reinstalling nor a new device restarts the trial.
    public static func trialStart(_ dates: [Date?], fallback: Date = Date()) -> Date {
        dates.compactMap { $0 }.min() ?? fallback
    }
}
