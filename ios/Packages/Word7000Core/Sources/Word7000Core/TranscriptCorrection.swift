import Foundation

/// Fixes what speech recognition wrote wrong without the learner having said
/// it wrong, and only that: in Chinese, characters that sound exactly like
/// the turn's key phrase (same syllables, same tones) but were written as
/// other characters become the key phrase. Grammar and wrong words are left
/// for the learner and the coach. Every fix is reported so it can be shown
/// and undone.
public enum TranscriptCorrection {
    public struct Fix: Equatable, Sendable {
        public let heard: String
        public let corrected: String
    }

    public static func correct(_ text: String, keyPhrase: String, chinese: Bool) -> (text: String, fixes: [Fix]) {
        guard chinese else { return (text, []) }
        let key = Array(keyPhrase.filter(ChineseDisplay.isHan))
        guard key.count >= 2 else { return (text, []) }
        let keySounds = key.map { ShadowingCheck.characterPinyin(String($0)) }
        guard keySounds.allSatisfy({ !$0.isEmpty }) else { return (text, []) }
        var characters = Array(text)
        var fixes: [Fix] = []
        var index = 0
        while index + key.count <= characters.count {
            let window = Array(characters[index..<(index + key.count)])
            if window != key, window.allSatisfy(ChineseDisplay.isHan),
               window.map({ ShadowingCheck.characterPinyin(String($0)) }) == keySounds {
                fixes.append(Fix(heard: String(window), corrected: String(key)))
                characters.replaceSubrange(index..<(index + key.count), with: key)
                index += key.count
            } else {
                index += 1
            }
        }
        return (String(characters), fixes)
    }

    /// Puts what was heard back.
    public static func undo(_ fixes: [Fix], in text: String) -> String {
        fixes.reduce(text) { result, fix in
            guard let range = result.range(of: fix.corrected) else { return result }
            return result.replacingCharacters(in: range, with: fix.heard)
        }
    }
}
