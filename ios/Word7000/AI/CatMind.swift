import Foundation
import Observation
import SwiftUI
import Word7000Core

/// What 小笨貓 remembers about the learner: an exam date, a goal, what to call
/// them and a few short notes. Kept only on this iPhone; sent along with the
/// cat's AI requests so it can talk about them. The learner can see, change
/// and wipe all of it in Me.
@MainActor @Observable
final class CatMemory {
    static let shared = CatMemory()

    struct Saved: Codable, Equatable {
        var examDate: String?
        var goal: String?
        var nickname: String?
        var notes: [String] = []
    }

    static let maxNotes = 8
    private static let key = "word7000.catMemory"
    private(set) var saved: Saved {
        didSet {
            if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: Self.key) }
        }
    }

    private init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingReset") {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
        saved = UserDefaults.standard.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } ?? Saved()
        if AppRuntime.catShowcase {
            saved = Saved(examDate: "2027-01-16", goal: L.t("學測英文 15 級分", "Top marks in the exam"), nickname: L.t("阿明", "Sam"),
                          notes: [L.t("介係詞常錯", "Mixes up prepositions"), L.t("晚上比較有空", "Studies best at night")])
        }
    }

    var isEmpty: Bool { saved == Saved() }

    var examDate: String? {
        get { saved.examDate }
        set { saved.examDate = newValue.flatMap { DayMath.dayNumber($0) == nil ? nil : $0 } }
    }
    var goal: String? {
        get { saved.goal }
        // Trimmed when sent, not as it is typed, so spaces can be typed.
        set { saved.goal = newValue?.nilIfEmpty.map { String($0.prefix(80)) } }
    }
    var nickname: String? {
        get { saved.nickname }
        set { saved.nickname = newValue?.nilIfEmpty.map { String($0.prefix(20)) } }
    }
    var notes: [String] { saved.notes }

    /// Days left until the exam, or nil without a date (or once it has passed).
    var daysToExam: Int? {
        guard let examDate, let exam = DayMath.dayNumber(examDate), let today = DayMath.dayNumber(DayMath.today()) else { return nil }
        let days = exam - today
        return days >= 0 ? days : nil
    }

    /// Takes what the cat was told to remember; returns what changed, to show.
    @discardableResult
    func apply(_ memory: CloudAI.ChatReply.Memory) -> [String] {
        var changed: [String] = []
        if !memory.examDate.isEmpty, memory.examDate != examDate {
            examDate = memory.examDate
            changed.append(L.t("考試日 \(memory.examDate)", "exam on \(memory.examDate)"))
        }
        if !memory.goal.isEmpty, memory.goal != goal {
            goal = memory.goal
            changed.append(L.t("目標：\(memory.goal)", "goal: \(memory.goal)"))
        }
        if !memory.nickname.isEmpty, memory.nickname != nickname {
            nickname = memory.nickname
            changed.append(L.t("叫你「\(memory.nickname)」", "calling you \u{201C}\(memory.nickname)\u{201D}"))
        }
        let note = memory.note.trimmed
        if !note.isEmpty, !saved.notes.contains(note) {
            saved.notes = Array((saved.notes + [String(note.prefix(80))]).suffix(Self.maxNotes))
            changed.append(note)
        }
        return changed
    }

    func removeNote(_ note: String) { saved.notes.removeAll { $0 == note } }
    func forgetAll() { saved = Saved() }
}

extension String {
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// "Core 6" or "Core 6–7", from an ability in half-levels.
enum CatLevel {
    static let top = 14
    /// Fewer Core words met than this and the estimate is mostly a guess.
    static let wordsNeeded = 10

    static func name(_ ability: Int) -> String {
        let level = ability / 2
        if level < 1 { return "Core 1" }
        if level >= top { return "Core \(top)" }
        return ability % 2 == 0 ? "Core \(level)" : "Core \(level)–\(level + 1)"
    }
}

/// The few facts the cat works from, gathered once per line or request.
struct CatContext {
    var level: String?
    var streak: Int
    var studiedToday: Int
    var dailyGoal: Int
    var daysToExam: Int?
    var nickname: String?
    var hour: Int

    /// How the cat addresses the learner, with a trailing comma, or nothing.
    var callout: String { nickname.map { L.t("\($0)，", "\($0), ") } ?? "" }
}

extension AppModel {
    @MainActor var catContext: CatContext {
        let estimate = LearningEngine.abilityEstimate(words: vocabularyWords, state: progress)
        return CatContext(
            level: estimate.seen >= CatLevel.wordsNeeded ? CatLevel.name(estimate.ability) : nil,
            streak: max(0, progress.streak), studiedToday: progress.studiedToday, dailyGoal: progress.dailyTarget,
            daysToExam: CatMemory.shared.daysToExam, nickname: CatMemory.shared.nickname?.trimmed.nilIfEmpty,
            hour: Calendar.current.component(.hour, from: Date()))
    }

    /// The learner as the cat's AI requests describe them (`profile` on the server).
    @MainActor func catProfile() -> JSONValue {
        let context = catContext
        let stats = self.stats
        let memory = CatMemory.shared
        var profile: [String: JSONValue] = [
            "today": .string(today),
            "streak": .number(Double(context.streak)),
            "studiedToday": .number(Double(max(0, context.studiedToday))),
            "dailyGoal": .number(Double(max(1, context.dailyGoal))),
            "due": .number(Double(stats.due)),
            "mastered": .number(Double(stats.mastered)),
            "reviewing": .number(Double(stats.review)),
            "notes": .array(memory.notes.map { .string($0) }),
        ]
        if let level = context.level { profile["level"] = .string(level) }
        if let exam = memory.examDate { profile["examDate"] = .string(exam) }
        if let days = context.daysToExam { profile["daysToExam"] = .number(Double(days)) }
        if let goal = memory.goal?.trimmed, !goal.isEmpty { profile["goal"] = .string(goal) }
        if let nickname = memory.nickname?.trimmed, !nickname.isEmpty { profile["nickname"] = .string(nickname) }
        return .object(profile)
    }

    /// Words the cat can bring up: the most forgotten first, then ones due.
    @MainActor func catWords(limit: Int) -> [(word: WordEntry, misses: Int)] {
        let today = self.today
        return bank.words
            .compactMap { word -> (WordEntry, WordProgress)? in
                guard let progress = progress.words[word.id], progress.status != .new else { return nil }
                let struggling = progress.status == .review || (progress.lapses ?? 0) > 0
                return struggling || LearningEngine.isDue(progress, today: today) ? (word, progress) : nil
            }
            .sorted { ($0.1.lapses ?? 0, $0.1.reviewCount) > ($1.1.lapses ?? 0, $1.1.reviewCount) }
            .prefix(limit)
            .map { ($0.0, max($0.1.lapses ?? 0, $0.1.reviewCount)) }
    }

    @MainActor func catWordsInput(limit: Int) -> JSONValue {
        .array(catWords(limit: limit).map { entry in
            .object([
                "id": .string(entry.word.id),
                "word": .string(String(face(entry.word).prompt.prefix(80))),
                "meaning": .string(String(ChineseDisplay.conciseMeaning(entry.word.meaningZh).prefix(120))),
                "misses": .number(Double(min(999, entry.misses))),
            ])
        })
    }
}

/// Today's AI-written lines for the cat, one pack a day per study mode.
enum CatLinePackStore {
    private struct Saved: Codable {
        var day: String
        var mode: String
        var pack: CloudAI.LinePack
    }
    private static let key = "word7000.catLines"

    static func today(mode: StudyMode) -> CloudAI.LinePack? {
        guard !AppRuntime.uiTesting,
              let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              saved.day == DayMath.today(), saved.mode == mode.rawValue else { return nil }
        return saved.pack
    }

    static func save(_ pack: CloudAI.LinePack, mode: StudyMode) {
        guard let data = try? JSONEncoder().encode(Saved(day: DayMath.today(), mode: mode.rawValue, pack: pack)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Fetches today's pack once, in the background, when the online AI is
    /// already allowed (never asks for consent for this).
    @MainActor static func refreshIfNeeded(_ model: AppModel) async {
        guard !AppRuntime.uiTesting, today(mode: model.studyMode) == nil,
              CloudAssistant.shared.ready, IntelligenceSettings.shared.cloudAllowed else { return }
        // Leave room for what the learner asks for themselves.
        if let usage = CloudAssistant.shared.usage, usage.remaining < 6 { return }
        let mode = model.studyMode
        let input: [String: JSONValue] = [
            "mode": .string(mode.rawValue),
            "profile": model.catProfile(),
            "words": .array(model.catWords(limit: 8).map { .string(String(model.face($0.word).prompt.prefix(80))) }),
        ]
        guard let pack = try? await CloudAssistant.shared.run(.lines, input, as: CloudAI.LinePack.self).cleaned() else { return }
        save(pack, mode: mode)
    }
}

/// What the cat remembers, to read, change or wipe. Only on this iPhone.
struct CatMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var memory = CatMemory.shared
    @State private var confirmForget = false

    var body: some View {
        Form {
            Section {
                CatSays(mood: .smug, size: 34) {
                    Text(memory.isEmpty
                         ? L.t("我記性很好，只是你都不跟我說。聊天時說「幫我記住…」就好。",
                               "My memory's great. You just never tell me anything. Say \u{201C}remember…\u{201D} in a chat.")
                         : L.t("這些我都記著。你忘了沒關係，我不會。",
                               "I remember all of this. You may forget; I won't."))
                        .font(.subheadline)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            Group {
                Section {
                    Toggle(L.t("考試日期", "Exam date"), isOn: Binding(
                        get: { memory.examDate != nil },
                        set: { on in memory.examDate = on ? (memory.examDate ?? defaultExamDate) : nil }
                    ))
                    .accessibilityIdentifier("cat-memory-exam-toggle")
                    if memory.examDate != nil {
                        DatePicker(L.t("哪一天", "Date"), selection: Binding(
                            get: { date(memory.examDate) ?? Date() },
                            set: { memory.examDate = string($0) }
                        ), in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    if let days = memory.daysToExam { Text(L.t("還有 \(days) 天", "\(days) days to go")) }
                }
                Section(L.t("目標", "Goal")) {
                    TextField(L.t("例如：學測英文 15 級分", "e.g. pass the exam with top marks"), text: Binding(
                        get: { memory.goal ?? "" }, set: { memory.goal = $0 }))
                        .accessibilityIdentifier("cat-memory-goal")
                }
                Section(L.t("怎麼叫你", "What to call you")) {
                    TextField(L.t("例如：阿明", "e.g. Sam"), text: Binding(
                        get: { memory.nickname ?? "" }, set: { memory.nickname = $0 }))
                        .accessibilityIdentifier("cat-memory-nickname")
                }
                if !memory.notes.isEmpty {
                    Section(L.t("小笨貓的筆記", "Silly Cat's notes")) {
                        ForEach(memory.notes, id: \.self) { note in
                            Text(note)
                                .swipeActions { Button(role: .destructive) { memory.removeNote(note) } label: { Label(L.t("刪除", "Delete"), systemImage: "trash") } }
                        }
                    }
                }
                Section {
                    Button(L.t("全部忘掉", "Forget everything"), role: .destructive) { confirmForget = true }
                        .disabled(memory.isEmpty)
                } footer: {
                    Text(L.t("只存在這支 iPhone，跟小笨貓聊天時才會一起送出。", "Kept on this iPhone; sent only with your chats."))
                }
            }
            .listRowBackground(StyledRowBackground())
        }
        .warmList()
        .navigationTitle(L.t("小笨貓記得的事", "What Silly Cat remembers"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L.t("要小笨貓全部忘掉？", "Make Silly Cat forget everything?"), isPresented: $confirmForget, titleVisibility: .visible) {
            Button(L.t("全部忘掉", "Forget everything"), role: .destructive) { memory.forgetAll() }
            Button(L.cancel, role: .cancel) {}
        } message: {
            Text(L.t("好啦，你都不要我記得你。", "Fine. You don't want me to remember you."))
        }
    }

    /// The next mid-January, roughly when the GSAT is held.
    private var defaultExamDate: String {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        var components = DateComponents(year: calendar.component(.year, from: now), month: 1, day: 15)
        if let date = calendar.date(from: components), date < now { components.year = (components.year ?? 0) + 1 }
        return string(calendar.date(from: components) ?? now)
    }

    private func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func string(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
