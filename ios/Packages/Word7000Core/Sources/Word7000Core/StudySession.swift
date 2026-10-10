import Foundation

public enum StudyGrade: String, Codable, Sendable {
    case known, review
}

/// One run through a stack of cards, ported from `src/lib/studySession.ts`.
public struct StudySession: Codable, Equatable, Sendable {
    /// A missed card comes back a few cards later, while the answer is still
    /// fresh enough to be worth a second look but not so soon that it is just
    /// recalled from the screen a moment ago.
    public static let requeueGap = 4
    static let maxRequeuesPerCard = 2

    /// Card ids in the order they will be shown, including re-queued misses.
    public private(set) var cardIds: [String]
    public private(set) var index: Int
    /// Distinct words in the session as it was built, for the summary.
    public let initialCount: Int
    public private(set) var knownIds: [String]
    public private(set) var reviewIds: [String]
    /// What the session was built from; a different key means rebuild.
    public let sourceKey: String
    public private(set) var requeued: [String: Int]

    public init(cardIds: [String], sourceKey: String) {
        var seen = Set<String>()
        let unique = cardIds.filter { seen.insert($0).inserted }
        self.cardIds = unique
        self.index = 0
        self.initialCount = unique.count
        self.knownIds = []
        self.reviewIds = []
        self.sourceKey = sourceKey
        self.requeued = [:]
    }

    public var currentCardId: String? { cardIds.indices.contains(index) ? cardIds[index] : nil }
    public var upcomingCardId: String? { cardIds.indices.contains(index + 1) ? cardIds[index + 1] : nil }
    public var isComplete: Bool { index >= cardIds.count }
    public var done: Int { min(index, cardIds.count) }
    public var total: Int { cardIds.count }

    /// Grades the card on screen. A grade for any other card is ignored.
    public func grading(_ cardId: String, as grade: StudyGrade) -> StudySession {
        guard currentCardId == cardId else { return self }
        var next = self
        let timesRequeued = requeued[cardId] ?? 0
        if grade == .review, timesRequeued < Self.maxRequeuesPerCard {
            let insertAt = min(cardIds.count, index + 1 + Self.requeueGap)
            next.cardIds.insert(cardId, at: insertAt)
            next.requeued[cardId] = timesRequeued + 1
        }
        // The summary reports each word once, by the last answer given for it.
        next.knownIds.removeAll { $0 == cardId }
        next.reviewIds.removeAll { $0 == cardId }
        if grade == .known { next.knownIds.append(cardId) } else { next.reviewIds.append(cardId) }
        next.index += 1
        return next
    }
}
