import Foundation
import Word7000Core

// Compiled alongside the production Persistence.swift by the Node runner.
// Only UI-only preference enums are supplied by that runner.
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}

func roundTrip(_ settings: AppSettings) throws -> AppSettings {
    try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
}

var settings = AppSettings()
settings.recentSpeakingIds = ["guest-old"]
settings.migrateSpeakingHistory()
check(settings.currentRecentSpeakingIds == ["guest-old"], "Unowned legacy data belongs only to the guest")
check(settings.recentSpeakingIds == nil, "Legacy history is consumed")
settings.setLocalOwner("guest-server-id", anonymous: true)
check(settings.currentRecentSpeakingIds == ["guest-old"], "Anonymous bootstrap retains the local guest history")
settings.rememberSpeaking("guest-new")
settings.setLocalOwner("A", anonymous: false)
check(settings.currentRecentSpeakingIds.isEmpty, "Signing in must not inherit guest history")
settings.rememberSpeaking("a-first")
settings.rememberSpeaking("a-second")
settings.rememberSpeaking("a-first")
check(settings.currentRecentSpeakingIds == ["a-second", "a-first"], "Recency order and deduplication are retained")
settings.setLocalOwner("B", anonymous: false)
check(settings.currentRecentSpeakingIds.isEmpty, "A new account must not inherit A's history")
settings.rememberSpeaking("b-only")
settings = try roundTrip(settings)
settings.setLocalOwner("A", anonymous: false)
check(settings.currentRecentSpeakingIds == ["a-second", "a-first"], "A's history survives restart and A-B-A switching")
settings.setLocalOwner(nil, anonymous: true)
check(settings.currentRecentSpeakingIds.isEmpty, "Sign-out starts a separate local guest")
settings.rememberSpeaking("offline-after-signout")
settings.setLocalOwner("another-guest-id", anonymous: true)
check(settings.currentRecentSpeakingIds == ["offline-after-signout"], "A new anonymous ID receives only the current local guest history")
settings.setLocalOwner("guest-server-id", anonymous: true)
check(settings.currentRecentSpeakingIds == ["guest-old", "guest-new"], "Returning to the original anonymous ID restores only its history")
settings.setLocalOwner("another-guest-id", anonymous: false)
check(settings.currentRecentSpeakingIds.isEmpty, "Switching to a different permanent ID cannot claim even that ID's saved guest history")
settings.setLocalOwner("B", anonymous: false)
check(settings.currentRecentSpeakingIds == ["b-only"], "B retains its own history")
settings.forgetSpeakingHistory(ownerId: "A", anonymous: false)
check(settings.currentRecentSpeakingIds == ["b-only"], "Deleting A must not delete B")
settings.setLocalOwner("A", anonymous: false)
check(settings.currentRecentSpeakingIds.isEmpty, "Deleted account history cannot reappear")
settings.setLocalOwner("guest-server-id", anonymous: true)
check(settings.currentRecentSpeakingIds == ["guest-old", "guest-new"], "Deleting A must not delete the guest")
settings.forgetSpeakingHistory(ownerId: "another-guest-id", anonymous: true)
check(settings.currentRecentSpeakingIds == ["guest-old", "guest-new"], "Deleting another anonymous ID must not delete the current guest")
settings.setLocalOwner("another-guest-id", anonymous: true)
check(settings.currentRecentSpeakingIds.isEmpty, "Deleting an anonymous account clears its guest history")
settings = try roundTrip(settings)
settings.migrateSpeakingHistory()
check(settings.currentRecentSpeakingIds.isEmpty, "Deleted anonymous history cannot be recreated by migration after restart")
settings.setLocalOwner(nil, anonymous: true)
settings.setLocalOwner("third-guest-id", anonymous: true)
check(settings.currentRecentSpeakingIds.isEmpty, "Previously claimed local guest history cannot seed another anonymous account")

var linking = AppSettings()
linking.setLocalOwner("linked", anonymous: true)
linking.rememberSpeaking("shared")
linking.rememberSpeaking("guest-latest")
linking.speakingHistoryByOwner?["account:linked"] = ["account-only", "shared"]
linking.speakingHistoryByOwner?["account:other"] = ["other-only"]
var differentAccount = linking
differentAccount.setLocalOwner("other", anonymous: false)
check(differentAccount.currentRecentSpeakingIds == ["other-only"], "A different permanent account receives no anonymous history")
differentAccount.setLocalOwner("linked", anonymous: true)
check(differentAccount.currentRecentSpeakingIds == ["shared", "guest-latest"], "Switching to another account leaves the original anonymous history intact")

linking.setLocalOwner("linked", anonymous: false)
check(linking.currentRecentSpeakingIds == ["account-only", "shared", "guest-latest"], "Same-ID linking merges both histories with current guest practice most recent")
check(linking.speakingHistoryByOwner?["guest:linked"] == nil, "Same-ID linking moves rather than copies the anonymous history")
check(linking.speakingHistoryByOwner?["account:other"] == ["other-only"], "Linking does not change another account")
linking = try roundTrip(linking)
linking.setLocalOwner("linked", anonymous: false)
check(linking.currentRecentSpeakingIds == ["account-only", "shared", "guest-latest"], "Linked history survives restart and repeated activation without duplicates")
linking.forgetSpeakingHistory(ownerId: "linked", anonymous: false)
linking.setLocalOwner("linked", anonymous: true)
check(linking.currentRecentSpeakingIds.isEmpty, "Deleted linked history cannot return from an old anonymous copy")
linking.setLocalOwner("linked", anonymous: false)
check(linking.currentRecentSpeakingIds.isEmpty, "Relinking cannot recreate deleted history")

var legacyLink = AppSettings()
legacyLink.localOwnerId = "legacy-linked"
legacyLink.localOwnerIsAnonymous = true
legacyLink.recentSpeakingIds = ["legacy-question"]
legacyLink.setLocalOwner("legacy-linked", anonymous: false)
check(legacyLink.currentRecentSpeakingIds == ["legacy-question"], "Same-ID linking also preserves unmigrated legacy history")
check(legacyLink.recentSpeakingIds == nil && legacyLink.speakingHistoryByOwner?["guest:legacy-linked"] == nil, "Legacy linking leaves no old copy to replay")

var boundedLink = AppSettings()
boundedLink.setLocalOwner("bounded", anonymous: true)
boundedLink.speakingHistoryByOwner?["account:bounded"] = (0..<SpeakingPractice.recentLimit).map { "word-\($0)" }
boundedLink.rememberSpeaking("word-\(SpeakingPractice.recentLimit - 1)")
boundedLink.rememberSpeaking("word-\(SpeakingPractice.recentLimit)")
boundedLink.setLocalOwner("bounded", anonymous: false)
check(boundedLink.currentRecentSpeakingIds == (1...SpeakingPractice.recentLimit).map { "word-\($0)" }, "Linking deduplicates overlap, drops the oldest entry and retains exactly the history limit")

for anonymous in [false, true] {
    var old = AppSettings()
    old.localOwnerId = "legacy-owner"
    old.localOwnerIsAnonymous = anonymous
    old.recentSpeakingIds = ["legacy"]
    old = try roundTrip(old)
    check(old.speakingHistoryByOwner == nil, "Old settings decode without the new field")
    // Migration must happen before assigning the incoming account, even if
    // the launch-time migration was skipped by a future caller.
    old.setLocalOwner("new-owner", anonymous: false)
    check(old.currentRecentSpeakingIds.isEmpty, "Migration never assigns old history to the incoming account")
    old.setLocalOwner("legacy-owner", anonymous: anonymous)
    check(old.currentRecentSpeakingIds == ["legacy"], "Migration preserves the recorded previous owner")
    old = try roundTrip(old)
    old.recentSpeakingIds = ["stale-backup"]
    old.migrateSpeakingHistory()
    check(old.currentRecentSpeakingIds == ["legacy"], "A stale legacy field cannot overwrite an already migrated history")
    check(old.recentSpeakingIds == nil, "The stale legacy field is also discarded")
    old.setLocalOwner("third-owner", anonymous: false)
    check(old.currentRecentSpeakingIds.isEmpty, "Repeated migration cannot seed subsequent accounts")
}

var unknown = AppSettings()
unknown.localOwnerId = "old-account-without-anonymous-flag"
unknown.recentSpeakingIds = ["old"]
unknown.migrateSpeakingHistory()
unknown.setLocalOwner(nil, anonymous: true)
check(unknown.currentRecentSpeakingIds.isEmpty, "A recorded owner with a missing flag must not leak into guest history")
unknown.setLocalOwner("old-account-without-anonymous-flag", anonymous: false)
check(unknown.currentRecentSpeakingIds == ["old"], "The older owner still retains its history")

var capped = AppSettings()
capped.recentSpeakingIds = (0..<400).map { "word-\($0)" }
capped.migrateSpeakingHistory()
check(capped.currentRecentSpeakingIds.count == SpeakingPractice.recentLimit, "Migration retains the history limit")
check(capped.currentRecentSpeakingIds.first == "word-100", "Migration keeps the most recent history")
capped.rememberSpeaking("last")
check(capped.currentRecentSpeakingIds.count == SpeakingPractice.recentLimit, "New practice remains bounded")
check(capped.currentRecentSpeakingIds.last == "last", "Latest practice is last")

let candidates = ["one", "two"].map {
    WordEntry(id: $0, word: $0, partOfSpeech: "n.", pronunciation: "",
              meaningZh: "", example: "", exampleZh: "", group: "test")
}
var selection = AppSettings()
selection.setLocalOwner("A", anonymous: false)
selection.rememberSpeaking("one")
selection.setLocalOwner("B", anonymous: false)
selection.rememberSpeaking("two")
check(SpeakingPractice.session(from: candidates, recent: selection.currentRecentSpeakingIds, count: 1, seed: "same").map(\.id) == ["one"], "B's questions ignore only B's recent practice")
selection.setLocalOwner("A", anonymous: false)
check(SpeakingPractice.session(from: candidates, recent: selection.currentRecentSpeakingIds, count: 1, seed: "same").map(\.id) == ["two"], "A's questions ignore only A's recent practice")

var alreadyMigrated = AppSettings()
alreadyMigrated.speakingHistoryByOwner = [:]
alreadyMigrated.recentSpeakingIds = ["must-not-return"]
alreadyMigrated.setLocalOwner("new", anonymous: false)
check(alreadyMigrated.currentRecentSpeakingIds.isEmpty, "An empty migrated map never reseeds history")
alreadyMigrated.setLocalOwner(nil, anonymous: true)
check(alreadyMigrated.currentRecentSpeakingIds.isEmpty, "An empty migrated guest history stays empty too")

var preferences = AppSettings()
preferences.theme = .dark
preferences.activeBankId = "custom-bank"
preferences.quizQuestionCount = 20
preferences.studyMode = .chinese
preferences.streakReminder = false
preferences.reminderMinute = 780
preferences.hapticsEnabled = false
preferences.speakingActivity = .examples
preferences.speakingFilter = FilterSelection(status: .favorites, level: "Core 1", initial: "a", sort: .alphabetical)
preferences.savedBankFilters = ["custom-bank": BankFilterSettings()]
preferences.onboardingComplete = true
preferences.migratedLegacyData = true
preferences.permanentAccountUsed = true
let before = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as! [String: Any]
preferences.recentSpeakingIds = ["old"]
preferences.migrateSpeakingHistory()
preferences.setLocalOwner("A", anonymous: false)
preferences.rememberSpeaking("new")
preferences.forgetSpeakingHistory(ownerId: "A", anonymous: false)
preferences.setLocalOwner(nil, anonymous: true)
preferences = try roundTrip(preferences)
let after = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as! [String: Any]
for (key, value) in before {
    guard let saved = after[key] else { fatalError("Preference missing: \(key)") }
    let originalJSON = try JSONSerialization.data(withJSONObject: [key: value], options: .sortedKeys)
    let savedJSON = try JSONSerialization.data(withJSONObject: [key: saved], options: .sortedKeys)
    check(originalJSON == savedJSON, "Preference changed: \(key)")
}

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
defer { try? FileManager.default.removeItem(at: directory) }
let persistence = Persistence(directory: directory)
settings.setLocalOwner("B", anonymous: false)
let snapshot = AppSnapshot(progress: .empty, customSets: .empty, settings: settings, studySession: nil, sessionDay: nil)
check(persistence.save(snapshot, to: "snapshot.json"), "Saving the actual app snapshot succeeds")
let loaded = persistence.load(AppSnapshot.self, from: "snapshot.json")
check(loaded?.settings.currentRecentSpeakingIds == ["b-only"], "The actual persistence layer restores the current account history")
check(loaded?.settings.speakingHistoryByOwner == settings.speakingHistoryByOwner, "All account histories survive disk persistence")
print("Speaking recency: \(checks) checks passed")
