import SwiftUI
import Word7000Core

/// Which words a round or a list uses: WordCat's own chips throughout (it
/// used the iPhone's pop-up menus and pickers, out of place on the paper).
struct FilterControls: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: FilterSelection
    var includesSort = false
    @State private var lettersOpen = false

    var body: some View {
        ChoiceRow(title: L.filterStatus, icon: "line.3.horizontal.decrease.circle.fill", tint: Palette.accent,
                  options: LibraryFilter.allCases.map { ChoiceOption(value: $0, title: L.filterLabel($0)) },
                  selection: selection.status, equalWidths: false, identifier: "filter-status") { selection.status = $0 }
        // Several chapters at once (say 3 to 5): each chip turns on or off.
        VStack(alignment: .leading, spacing: 10) {
            // The chips say it when every chapter is in; the row names a choice.
            SettingsLabel(L.filterLevel, icon: "books.vertical.fill", tint: Palette.chinese,
                          value: selection.levels.isEmpty ? nil : L.levelSummary(selection.levels),
                          trigger: AnyHashable(selection.level))
            FlowLayout(spacing: 8, lineSpacing: 8) {
                chip(L.allLevels, on: selection.levels.isEmpty, identifier: "filter-level-all") { selection.level = "all" }
                ForEach(model.levels, id: \.self) { group in
                    chip(Self.shortLevel(group), on: selection.levels.contains(group), identifier: "filter-level-\(group)") {
                        selection.toggleLevel(group, order: model.levels)
                    }
                    .accessibilityLabel(L.levelName(group))
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filter-level")
        // Twenty-six letters fold away until wanted. Learners of Chinese have
        // no first letter to go by (the bank's words are Chinese).
        if model.studyMode == .english {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : Motion.reveal) { lettersOpen.toggle() }
            } label: {
                HStack {
                    SettingsLabel(L.t("開頭字母", "First letter"), icon: "character.textbox", tint: Palette.known,
                                  value: selection.initial == "all" ? L.t("全部", "All") : selection.initial)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.secondaryLabel)
                        .rotationEffect(.degrees(lettersOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filter-initial")
            if lettersOpen {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    chip(L.t("全部", "All"), on: selection.initial == "all", identifier: "filter-initial-all") { selection.initial = "all" }
                    ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init), id: \.self) { letter in
                        chip(letter, on: selection.initial == letter, identifier: "filter-initial-\(letter)", square: true) {
                            selection.initial = letter
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        }
        if includesSort {
            ChoiceRow(title: L.filterSort, icon: "arrow.up.arrow.down", tint: Palette.review,
                      options: [ChoiceOption(value: LibrarySort.default, title: L.sortDefault),
                                ChoiceOption(value: LibrarySort.alphabetical, title: L.sortAlphabetical)],
                      selection: selection.sort, identifier: "filter-sort") { selection.sort = $0 }
        }
        if selection.isActive {
            Button {
                withAnimation(reduceMotion ? nil : Motion.reveal) {
                    selection.status = .all
                    selection.level = "all"
                    selection.initial = "all"
                }
            } label: {
                Label(L.t("清除篩選", "Clear filters"), systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.accent)
            }
            .accessibilityIdentifier("filter-clear")
        }
    }

    /// "3" for a chapter of the built-in list (the row says Chapter); a
    /// scanned bank's group by its own name.
    static func shortLevel(_ group: String) -> String {
        LearningEngine.coreLevel(group).map(String.init) ?? group
    }

    /// One clay chip that turns on and off, as in Settings.
    private func chip(_ title: String, on: Bool, identifier: String, square: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : Motion.pop) { action() }
        } label: {
            HStack(spacing: 4) {
                if on, !square { Image(systemName: "checkmark").font(.caption.weight(.heavy)) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(on ? Palette.surface : Palette.ink)
            .padding(.horizontal, square ? 0 : 12)
            .frame(minWidth: square ? 36 : 40, minHeight: 36)
            .background { Capsule().fill(on ? AnyShapeStyle(Palette.accent.gradient) : AnyShapeStyle(Palette.fill)) }
            .overlay { Capsule().strokeBorder(on ? Color.clear : Palette.khaki.opacity(0.7), lineWidth: 1) }
            .contentShape(Capsule())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(identifier)
        .sensoryFeedback(.selection, trigger: on) { _, _ in model.settings.hapticsEnabled ?? true }
    }
}

struct StudySettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        FilterControls(selection: Binding(get: { model.settings.studyFilter }, set: { model.settings.studyFilter = $0 }))
                    } header: { Text(model.bankName) }
                    Section {
                        let count = model.studyCandidates.count
                        LabeledContent(L.t("符合條件", "Matching words")) {
                            Text(L.bankWordCount(count))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(count)))
                        }
                    }
                }
                .listRowBackground(StyledRowBackground())
            }
            .warmList()
            // The count rolls to its new value as the filters change.
            .animation(reduceMotion ? nil : Motion.reveal, value: model.settings.studyFilter)
            .sensoryFeedback(.selection, trigger: model.settings.studyFilter) { _, _ in model.settings.hapticsEnabled ?? true }
            .navigationTitle(L.t("學習範圍", "Study scope"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.done) { dismiss() } } }
        }
    }
}

struct QuizConfiguration: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var start: () -> Void
    @State private var scopeOpen = false

    private var selection: Binding<FilterSelection> {
        Binding(get: { model.settings.quizFilter }, set: { model.settings.quizFilter = $0 })
    }

    /// "7000 單字・全部" or the filters in use, in a few words.
    private func scopeSummary(_ filter: FilterSelection) -> String {
        guard filter.isActive else { return L.t("\(model.bankName) · 全部", "\(model.bankName) · all") }
        var parts: [String] = []
        if filter.status != .all { parts.append(L.filterLabel(filter.status)) }
        if !filter.levels.isEmpty { parts.append(L.levelSummary(filter.levels)) }
        if filter.initial != "all" { parts.append(L.t("\(filter.initial) 開頭", "starts with \(filter.initial)")) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let filter = model.settings.quizFilter
        let count = model.bank.filter(state: model.progress, query: "", filter: filter.status, options: filter.options).count
        Form {
            Group {
                Section {
                    ChoiceChips(options: QuizBuilder.questionCounts.map { ChoiceOption(value: $0, title: L.t("\($0) 題", "\($0)")) },
                                selection: model.settings.quizQuestionCount, identifier: "quiz-question-count") {
                        model.settings.quizQuestionCount = $0
                    }
                    .padding(.vertical, 4)
                } header: { Text(L.t("這次想練習幾題？", "How many questions?")) }
                // Which words: folded away, its summary on the row; most
                // rounds only change how many questions.
                Section {
                    DisclosureGroup(isExpanded: $scopeOpen) {
                        FilterControls(selection: selection)
                    } label: {
                        LabeledContent(L.t("範圍", "Words")) {
                            Text(scopeSummary(filter))
                                .lineLimit(1)
                                .foregroundStyle(filter.isActive ? Palette.accent : Palette.secondaryLabel)
                        }
                    }
                    .accessibilityIdentifier("quiz-scope")
                }
                // The count chosen above is the round's, unless the words in
                // range are fewer: only then is there anything to say.
                if count < model.settings.quizQuestionCount {
                    Section {
                        Label(count == 0 ? L.t("範圍裡沒有字，換個範圍再開始", "No words in range: widen it to start")
                                         : L.t("範圍裡只有 \(count) 個字，這輪考 \(count) 題", "Only \(count) words in range: \(count) questions this round"),
                              systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryLabel)
                            .accessibilityIdentifier("quiz-round-size")
                    }
                }
            }
            .listRowBackground(StyledRowBackground())
        }
        .warmList()
        // Always in reach at the bottom, even when the sheet is at half height.
        .safeAreaInset(edge: .bottom) {
            Button(action: start) {
                Text(L.t("開始測驗", "Start quiz")).font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .disabled(count == 0)
            .accessibilityIdentifier("quiz-start")
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background { PaperBarBackground() }
        }
        .navigationTitle(L.quickQuiz)
        .animation(reduceMotion ? nil : Motion.reveal, value: model.settings.quizQuestionCount)
        .animation(reduceMotion ? nil : Motion.reveal, value: model.settings.quizFilter)
        .sensoryFeedback(.selection, trigger: model.settings.quizQuestionCount) { _, _ in model.settings.hapticsEnabled ?? true }
        .sensoryFeedback(.selection, trigger: model.settings.quizFilter) { _, _ in model.settings.hapticsEnabled ?? true }
    }
}
