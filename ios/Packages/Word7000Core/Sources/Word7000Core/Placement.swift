import Foundation

/// The first-launch check of what a learner already knows: a few words from
/// across the levels, and the ones they say they know count as known on
/// sight. New words then start near their level instead of at the bottom.
public enum Placement {
    /// One word from each of these Core levels, easy to hard.
    public static let levels = [1, 3, 5, 6, 8, 9, 11, 12, 14]

    /// A word per level, short enough for a small card and a single word
    /// (no phrases), in a seeded order within each level.
    public static func words(from words: [WordEntry], seed: String) -> [WordEntry] {
        var byLevel: [Int: [WordEntry]] = [:]
        for word in words {
            guard let level = LearningEngine.coreLevel(word.group), levels.contains(level),
                  word.word.count <= 11, !word.word.contains(" "), !word.word.contains("-") else { continue }
            byLevel[level, default: []].append(word)
        }
        return levels.compactMap { level in
            SeededRandom.shuffle(byLevel[level] ?? [], seed: "\(seed):placement:\(level)").first
        }
    }

    /// The words the learner said they know, marked known on sight. Not
    /// study: the day's goal and the streak are left as they were, and a
    /// word already met is left alone.
    public static func apply(knownIds: [String], to state: ProgressState, today: String) -> ProgressState {
        var result = state
        for id in knownIds where result.progress(for: id).status == .new {
            let graded = LearningEngine.markKnown(result, wordId: id, today: today)
            result.words[id] = graded.words[id]
        }
        return result
    }
}
