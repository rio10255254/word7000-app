import SwiftUI
import Word7000Core

/// WordCat Next: the plan the first launch made, to read and to change:
/// the exam and its date, words a day, what to get better at, which of
/// words and speaking comes first, where new words start, and a new level
/// test. Every change shows at once in the plan at the top.
struct LearningPlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var memory = CatMemory.shared
    @State private var retestOpen = false
    /// New words met over the next month, and by the exam, counted the way
    /// sessions are built (LearningEngine.projectedNewWords).
    @State private var monthNew: Int?
    @State private var examNew: Int?
    /// What a focus just picked suggests, offered once, applied only on a tap.
    @State private var suggestion: Suggestion?

    enum Suggestion: Equatable {
        case target(Int)
        case lead(Pillar)
    }

    private let dailyTargetOptions = [10, 20, 30, 50]

    private var profile: LearnerProfile { model.settings.learnerProfile ?? LearnerProfile() }
    private var english: Bool { model.studyMode == .english }
    private var exam: WelcomeExam? { profile.exam.flatMap(WelcomeExam.init(rawValue:)) }
    private var usesBuiltInWords: Bool { model.settings.activeBankId == WordBanks.coreBankId }

    /// The chapter new words come from now: the test's, or the one being read.
    private var startChapter: Int {
        model.placementStart ?? (model.readingChapter.map { $0 + 1 } ?? 1)
    }

    /// Counts the pace again: after a change to the goal or the start.
    private func project() {
        monthNew = model.projectedNewWords(days: 30)
        examNew = memory.daysToExam.map { model.projectedNewWords(days: $0) }
    }

    private func update(_ change: (inout LearnerProfile) -> Void) {
        var changed = profile
        change(&changed)
        withAnimation(reduceMotion ? nil : Motion.reveal) { model.settings.learnerProfile = changed }
        model.scheduleSave()
    }

    var body: some View {
        Form {
            Group {
                Section { planCard }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                examSection
                dailySection
                if english { focusSection }
                startSection
            }
            .listRowBackground(StyledRowBackground())
        }
        .warmList()
        .onAppear(perform: project)
        .onChange(of: model.progress.dailyTarget) { _, _ in project() }
        .onChange(of: startChapter) { _, _ in project() }
        .onChange(of: memory.examDate) { _, _ in project() }
        .navigationTitle(L.t("我的學習計畫", "My learning plan"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $retestOpen) {
            WelcomeView(retest: true) { _, _, knownIds, learningIds, _ in
                model.applyPlacement(knownIds: knownIds, learningIds: learningIds)
                retestOpen = false
                model.saveNow()
            }
        }
    }

    // MARK: The plan

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("你的學習路線", "Your plan"))
                .font(.display(.title3, weight: .heavy))
                .foregroundStyle(Palette.ink)
            if usesBuiltInWords {
                row("book.fill", L.t("從第 \(startChapter) 章開始", "From chapter \(startChapter)"),
                    model.placementStart == nil ? L.t("還沒測過程度", "No level check yet") : L.t("太簡單的字直接跳過", "Words too easy for you are skipped"))
            } else {
                row("books.vertical.fill", L.t("正在學「\(model.bankName)」", "Studying \(model.bankName)"),
                    L.t("換回 7000 單字才照章節走", "Chapters follow the 7000-word list"))
            }
            row("plus.circle.fill", L.t("每天 \(model.progress.dailyTarget) 個字", "\(model.progress.dailyTarget) words a day"),
                monthNew.map { month in
                    L.t("新字和複習一起算；接下來一個月平均每天約 \(max(1, (month + 15) / 30)) 個新字",
                        "New words and reviews together; about \(max(1, (month + 15) / 30)) new a day this month")
                } ?? L.t("新字和該複習的字一起算", "New words and reviews together"))
            if english {
                row("pencil.line", L.t("翻卡後拼 \(profile.spellChecks) 個、考 \(profile.examChecks) 題", "Then spell \(profile.spellChecks) and answer \(profile.examChecks)"),
                    L.t("拼字穩了就少抽，退步了就多抽", "Fewer when spelling holds, more when it slips"))
            }
            row(model.settings.homeLead == .speaking ? "mic.fill" : "rectangle.on.rectangle.angled",
                model.settings.homeLead == .speaking ? L.t("每天先練口說", "Speaking first each day") : L.t("單字先，口說後", "Words first, then speaking"),
                L.t("兩個每天都有", "Both, every day"))
            if let days = memory.daysToExam, usesBuiltInWords, let examNew {
                let reach = PlacementTest.chaptersReached(from: startChapter, newWords: examNew)
                row("graduationcap.fill", L.t("\(exam?.title ?? "考試")前讀到第 \(reach) 章", "Chapter \(reach) by the exam"),
                    L.t("還有 \(days) 天，每天都學、複習也做完的話", "\(days) days left, studying every day with the reviews done"))
                    .accessibilityIdentifier("plan-reach")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { PremiumSurface(radius: 22) }
        .contentTransition(.numericText())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plan-card")
    }

    private func row(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Palette.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.footnote).foregroundStyle(Palette.secondaryLabel)
            }
        }
    }

    // MARK: Exam

    private var examSection: some View {
        Section {
            Picker(selection: Binding(
                get: { exam ?? .none },
                set: { choice in
                    update { $0.exam = choice.rawValue }
                    // The usual day of a school exam; an English test's day is the learner's own.
                    if let day = choice.date(after: Date()) {
                        memory.examDate = day
                    } else if choice == .none {
                        memory.examDate = nil
                    }
                }
            )) {
                ForEach(WelcomeExam.allCases, id: \.self) { choice in
                    Text(choice.title).tag(choice)
                }
            } label: {
                SettingsLabel(L.t("準備的考試", "Exam"), icon: "graduationcap.fill", tint: Palette.accent)
            }
            .accessibilityIdentifier("plan-exam")
            if (exam ?? .none) != .none {
                DatePicker(selection: Binding(
                    get: { memory.examDate.flatMap(Self.date(from:)) ?? Date() },
                    set: { memory.examDate = DayMath.today($0) }
                ), in: Date()..., displayedComponents: .date) {
                    SettingsLabel(L.t("考試日期", "Exam date"), icon: "calendar", tint: Palette.review)
                }
                .accessibilityIdentifier("plan-exam-date")
            }
        } header: {
            Text(L.t("考試", "Exam"))
        } footer: {
            Text(L.t("題型名稱和考前讀到第幾章，都照這裡算。", "The exam names the exam-style questions and sets the pace above."))
        }
    }

    private static func date(from day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // MARK: Each day

    private var dailySection: some View {
        Section {
            Picker(selection: Binding(get: { model.progress.dailyTarget }, set: { model.setDailyTarget($0) })) {
                ForEach(dailyTargetOptions, id: \.self) { value in
                    Text(L.wordsPerDay(value)).tag(value)
                }
            } label: {
                SettingsLabel(L.dailyTargetTitle, icon: "target", tint: Palette.accent, trigger: model.progress.dailyTarget)
            }
            .accessibilityIdentifier("plan-daily-target")
            Picker(selection: Binding(
                get: { model.settings.homeLead ?? .words },
                set: { model.settings.homeLead = $0 }
            )) {
                Text(L.t("先背單字", "Words first")).tag(Pillar.words)
                Text(L.t("先練口說", "Speaking first")).tag(Pillar.speaking)
            } label: {
                SettingsLabel(L.t("每天先做", "Each day starts with"), icon: "arrow.right.circle.fill", tint: Palette.known)
            }
            .accessibilityIdentifier("plan-lead")
        } header: {
            Text(L.t("每一天", "Each day"))
        }
    }

    // MARK: What to get better at

    private static var focuses: [(focus: LearnerProfile.Focus, icon: String, title: String, detail: String)] { [
        (.vocabulary, "books.vertical.fill", L.t("單字量", "More words"), L.t("建議每天多背一點", "A bigger daily goal is suggested")),
        (.spelling, "pencil.line", L.t("拼字", "Spelling"), L.t("翻卡後多抽幾個字拼", "More words to spell after the cards")),
        (.exam, "checklist", L.t("考試題型", "Exam questions"), L.t("翻卡後多考幾題", "More questions after the cards")),
        (.speaking, "mic.fill", L.t("口說", "Speaking"), L.t("口說的比重高一點", "More weight on speaking")),
    ] }

    private var focusSection: some View {
        Section {
            ForEach(Self.focuses, id: \.focus) { item in
                let on = profile.focus.contains(item.focus)
                Button {
                    update { $0.toggle(item.focus) }
                    suggest(after: item.focus)
                } label: {
                    HStack(spacing: 12) {
                        SettingsLabel(item.title, icon: item.icon, tint: on ? Palette.accent : Palette.secondaryLabel)
                        Spacer(minLength: 8)
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(on ? Palette.accent : Palette.tertiaryLabel)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(on ? L.t("已選", "Selected") : "")
                .accessibilityHint(item.detail)
                .accessibilityIdentifier("plan-focus-\(item.focus.rawValue)")
            }
            if let suggestion { suggestionRow(suggestion) }
        } header: {
            Text(L.t("想加強的（最多兩個）", "What to get better at (up to two)"))
        } footer: {
            Text(L.t("拼字、考試題型：改變每天翻卡後拼幾個、考幾題。單字量、口說：會建議每天的量和先做什麼，按「套用」才會改。",
                     "Spelling and exam questions change how many checks follow the cards. More words and speaking suggest your daily goal and what comes first; nothing changes until you tap Apply."))
        }
    }

    /// After a pick: what it suggests, when that differs from the plan now.
    private func suggest(after focus: LearnerProfile.Focus) {
        let picked = profile.focus.contains(focus)
        var next: Suggestion?
        switch focus {
        case .vocabulary:
            let wanted = profile.suggestedTarget
            if picked ? model.progress.dailyTarget < wanted : model.progress.dailyTarget > wanted { next = .target(wanted) }
        case .speaking:
            if profile.lead != (model.settings.homeLead ?? .words) { next = .lead(profile.lead) }
        case .spelling, .exam:
            next = nil
        }
        withAnimation(reduceMotion ? nil : Motion.reveal) { suggestion = next }
    }

    private func suggestionRow(_ suggestion: Suggestion) -> some View {
        let text: String
        switch suggestion {
        case .target(let count):
            text = L.t("建議每天 \(count) 個字（現在 \(model.progress.dailyTarget) 個）", "Suggested: \(count) words a day (now \(model.progress.dailyTarget))")
        case .lead(let lead):
            text = lead == .speaking ? L.t("建議每天先練口說", "Suggested: speaking first each day")
                                     : L.t("建議每天先背單字", "Suggested: words first each day")
        }
        return HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill").foregroundStyle(Palette.review)
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button(L.t("不用", "No")) {
                withAnimation(reduceMotion ? nil : Motion.reveal) { self.suggestion = nil }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Palette.secondaryLabel)
            .accessibilityIdentifier("plan-suggestion-dismiss")
            Button(L.t("套用", "Apply")) {
                switch suggestion {
                case .target(let count): model.setDailyTarget(count)
                case .lead(let lead): model.settings.homeLead = lead
                }
                model.scheduleSave()
                withAnimation(reduceMotion ? nil : Motion.reveal) { self.suggestion = nil }
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Palette.accent)
            .accessibilityIdentifier("plan-suggestion-apply")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan-suggestion")
    }

    // MARK: Where new words start

    private var startSection: some View {
        Section {
            if usesBuiltInWords {
                Stepper(value: Binding(
                    get: { startChapter },
                    set: { chapter in
                        update {
                            $0.startChapter = min(PlacementTest.topLevel, max(1, chapter))
                            $0.startMode = model.studyMode.rawValue
                        }
                    }
                ), in: 1...PlacementTest.topLevel) {
                    SettingsLabel(L.t("新字從第 \(startChapter) 章開始", "New words from chapter \(startChapter)"), icon: "book.fill", tint: Palette.chinese)
                }
                .accessibilityIdentifier("plan-start-chapter")
            }
            Button { retestOpen = true } label: {
                SettingsLabel(L.t("重新測程度", "Take the level check again"), icon: "arrow.triangle.2.circlepath", tint: Palette.review)
            }
            .tint(.primary)
            .accessibilityIdentifier("plan-retest")
        } header: {
            Text(L.t("程度", "Level"))
        } footer: {
            Text(L.t("兩分鐘看字選意思，再拼 3 個字；測完會換成新的起點。", "Two minutes of meanings and three words to spell; the result sets a new start."))
        }
    }
}
