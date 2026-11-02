import Foundation

/// Learning English and learning Chinese keep their own word progress:
/// knowing "adapt" does not mean being able to say 適應. Both live in one
/// stored record (so it syncs as before), the Chinese side under ids with a
/// `zh:` prefix; the streak, daily goal and activity are shared.
public enum ModeProgress {
    public static let chinesePrefix = "zh:"

    public static func isChineseKey(_ key: String) -> Bool { key.hasPrefix(chinesePrefix) }

    /// What one mode sees: its own words under their plain ids.
    public static func view(_ stored: ProgressState, chinese: Bool) -> ProgressState {
        var view = stored
        view.words = words(of: stored, chinese: chinese)
        return view
    }

    /// The words of one mode, under plain ids.
    public static func words(of stored: ProgressState, chinese: Bool) -> [String: WordProgress] {
        var words: [String: WordProgress] = [:]
        for (key, progress) in stored.words where isChineseKey(key) == chinese {
            words[chinese ? String(key.dropFirst(chinesePrefix.count)) : key] = progress
        }
        return words
    }

    /// The other mode's words, as stored (prefixed when they are Chinese).
    public static func storedWords(of stored: ProgressState, excluding chinese: Bool) -> [String: WordProgress] {
        stored.words.filter { isChineseKey($0.key) != chinese }
    }

    /// One mode's view put back beside the other mode's stored words.
    public static func store(_ view: ProgressState, chinese: Bool, otherWords: [String: WordProgress]) -> ProgressState {
        var stored = view
        var words = otherWords
        for (key, progress) in view.words {
            words[chinese ? chinesePrefix + key : key] = progress
        }
        stored.words = words
        return stored
    }

    /// Once, when the split arrives: a learner already learning Chinese keeps
    /// what they had (it was shared until now) on the Chinese side as well.
    public static func seedChinese(_ stored: ProgressState) -> ProgressState {
        guard !stored.words.keys.contains(where: isChineseKey) else { return stored }
        var seeded = stored
        for (key, progress) in stored.words { seeded.words[chinesePrefix + key] = progress }
        return seeded
    }
}
