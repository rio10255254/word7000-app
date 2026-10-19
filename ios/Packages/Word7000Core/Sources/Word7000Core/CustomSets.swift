import Foundation

/// Editing and merging the learner's own word sets, ported from
/// `src/lib/customSets.ts`. Every change stamps `updatedAt` so two devices can
/// merge by "newest wins".
extension CustomSetState {
    public func creatingSet(named name: String, now: String = DayMath.timestamp()) -> (state: CustomSetState, id: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = trimmed.isEmpty ? "我的單字集" : trimmed
        let id = uniqueSetId(name: cleanName, now: now)
        var next = self
        next.deletedSetIds = deletedSetIds?.filter { $0.key != id }
        next.sets.append(CustomVocabSet(
            color: WordBanks.nextColor(for: sets),
            createdAt: now,
            id: id,
            name: cleanName,
            sortOrder: sets.count + 1,
            updatedAt: now,
            wordIds: []
        ))
        return (next, id)
    }

    public func addingWord(_ wordId: String, toSet setId: String, now: String = DayMath.timestamp()) -> CustomSetState {
        updatingSet(setId, now: now) { set in
            if !set.wordIds.contains(wordId) { set.wordIds.insert(wordId, at: 0) }
        }
    }

    public func removingWord(_ wordId: String, fromSet setId: String, now: String = DayMath.timestamp()) -> CustomSetState {
        updatingSet(setId, now: now) { set in set.wordIds.removeAll { $0 == wordId } }
    }

    public func removingWords(_ ids: Set<String>, fromSet setId: String, now: String = DayMath.timestamp()) -> CustomSetState {
        updatingSet(setId, now: now) { $0.wordIds.removeAll { ids.contains($0) } }
    }

    public func renamingSet(_ setId: String, to name: String, now: String = DayMath.timestamp()) -> CustomSetState {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return self }
        return updatingSet(setId, now: now) { set in set.name = cleanName }
    }

    public func deletingSet(_ setId: String, now: String = DayMath.timestamp()) -> CustomSetState {
        var next = self
        var deleted = deletedSetIds ?? [:]
        deleted[setId] = now
        next.deletedSetIds = deleted
        next.sets = sets.filter { $0.id != setId }.enumerated().map { index, set in
            var copy = set
            copy.sortOrder = index + 1
            return copy
        }
        return next
    }

    public func restoringSet(_ set: CustomVocabSet, now: String = DayMath.timestamp()) -> CustomSetState {
        guard !sets.contains(where: { $0.id == set.id }) else { return self }
        var next = self
        var restored = set
        restored.updatedAt = now
        restored.sortOrder = next.sets.count + 1
        next.deletedSetIds?[set.id] = nil
        next.sets.append(restored)
        return next
    }

    public func transferringWords(_ ids: Set<String>, from sourceId: String, to targetId: String,
                                  move: Bool, now: String = DayMath.timestamp()) -> CustomSetState {
        guard sourceId != targetId, let source = sets.first(where: { $0.id == sourceId }),
              let target = sets.first(where: { $0.id == targetId }) else { return self }
        let selected = source.wordIds.filter { ids.contains($0) }
        let fresh = selected.filter { !target.wordIds.contains($0) }
        var next = updatingSet(targetId, now: now) { $0.wordIds.insert(contentsOf: fresh, at: 0) }
        if move { next = next.updatingSet(sourceId, now: now) { $0.wordIds.removeAll { ids.contains($0) } } }
        return next
    }

    public func editingWord(_ word: WordEntry, now: String = DayMath.timestamp()) -> CustomSetState {
        guard let index = customWords.firstIndex(where: { $0.id == word.id }) else { return self }
        var next = self
        var updated = word
        updated.updatedAt = now
        next.customWords[index] = updated
        for index in next.sets.indices where next.sets[index].wordIds.contains(word.id) {
            next.sets[index].updatedAt = now
        }
        return next
    }

    /// Saves (or replaces) hand-added or scanned words and puts them in a set.
    public func addingCustomWords(_ words: [WordEntry], toSet setId: String, now: String = DayMath.timestamp()) -> CustomSetState {
        var next = self
        for word in words {
            if let index = next.customWords.firstIndex(where: { $0.id == word.id }) {
                next.customWords[index] = word
            } else {
                next.customWords.insert(word, at: 0)
            }
        }
        return next.updatingSet(setId, now: now) { set in
            let fresh = words.map(\.id).filter { !set.wordIds.contains($0) }
            set.wordIds.insert(contentsOf: fresh, at: 0)
        }
    }

    func updatingSet(_ setId: String, now: String, _ change: (inout CustomVocabSet) -> Void) -> CustomSetState {
        var next = self
        next.sets = sets.map { set in
            guard set.id == setId else { return set }
            var copy = set
            change(&copy)
            copy.updatedAt = now
            return copy
        }
        return next
    }

    func uniqueSetId(name: String, now: String) -> String {
        let millis = PreparedVocabulary.parseDate(now).map { Int($0.timeIntervalSince1970 * 1000) } ?? Int(Date().timeIntervalSince1970 * 1000)
        let base = "set-\(name.split(whereSeparator: { $0.isWhitespace }).joined(separator: "-"))-\(millis)"
        let ids = Set(sets.map(\.id))
        guard ids.contains(base) else { return base }
        var suffix = 2
        while ids.contains("\(base)-\(suffix)") { suffix += 1 }
        return "\(base)-\(suffix)"
    }

    public static func merge(_ states: [CustomSetState?]) -> CustomSetState {
        var deleted: [String: String] = [:]
        for state in states.compactMap({ $0 }) {
            for (setId, deletedAt) in state.deletedSetIds ?? [:] where deleted[setId].map({ deletedAt > $0 }) ?? true {
                deleted[setId] = deletedAt
            }
        }

        var customWords: [WordEntry] = []
        var wordIndexes: [String: Int] = [:]
        var wordVersions: [String: String] = [:]
        var sets: [CustomVocabSet] = []
        var setIndexById: [String: Int] = [:]
        for state in states.compactMap({ $0 }) {
            var fallbackVersions: [String: String] = [:]
            for set in state.sets {
                for id in set.wordIds where set.updatedAt > (fallbackVersions[id] ?? "") {
                    fallbackVersions[id] = set.updatedAt
                }
            }
            for word in state.customWords {
                let version = word.updatedAt ?? fallbackVersions[word.id] ?? ""
                if let index = wordIndexes[word.id] {
                    if version >= (wordVersions[word.id] ?? "") { customWords[index] = word; wordVersions[word.id] = version }
                } else {
                    wordIndexes[word.id] = customWords.count
                    wordVersions[word.id] = version
                    customWords.append(word)
                }
            }
            for set in state.sets {
                if let deletedAt = deleted[set.id], deletedAt >= set.updatedAt { continue }
                if let existingIndex = setIndexById[set.id] {
                    let existing = sets[existingIndex]
                    let setTime = PreparedVocabulary.parseDate(set.updatedAt)?.timeIntervalSince1970 ?? 0
                    let existingTime = PreparedVocabulary.parseDate(existing.updatedAt)?.timeIntervalSince1970 ?? 0
                    if setTime >= existingTime { sets[existingIndex] = set }
                } else {
                    setIndexById[set.id] = sets.count
                    sets.append(set)
                }
            }
        }
        return CustomSetState(customWords: customWords, deletedSetIds: deleted, sets: sets)
    }
}
