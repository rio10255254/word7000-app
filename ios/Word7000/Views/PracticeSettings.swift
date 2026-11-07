import SwiftUI
import Word7000Core

struct FilterControls: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: FilterSelection
    var includesSort = false

    var body: some View {
        Picker(L.filterStatus, selection: $selection.status) {
            ForEach(LibraryFilter.allCases, id: \.self) { value in
                Text(L.filterLabel(value)).tag(value)
            }
        }
        // Several levels at once (say 3 to 5): the menu stays open while
        // they are ticked.
        LabeledContent(L.filterLevel) {
            Menu {
                Button { selection.level = "all" } label: {
                    if selection.levels.isEmpty { Label(L.allLevels, systemImage: "checkmark") } else { Text(L.allLevels) }
                }
                Divider()
                ForEach(model.levels, id: \.self) { group in
                    Button { selection.toggleLevel(group, order: model.levels) } label: {
                        if selection.levels.contains(group) { Label(L.levelName(group), systemImage: "checkmark") } else { Text(L.levelName(group)) }
                    }
                }
            } label: {
                Text(L.levelSummary(selection.levels))
                    .lineLimit(1)
                    .foregroundStyle(Palette.accent)
            }
            .menuActionDismissBehavior(.disabled)
            .accessibilityIdentifier("filter-level")
        }
        Picker(L.t("開頭字母", "First letter"), selection: $selection.initial) {
            Text(L.t("全部字母", "All letters")).tag("all")
            ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init), id: \.self) { Text($0).tag($0) }
        }
        if includesSort {
            Picker(L.filterSort, selection: $selection.sort) {
                Text(L.sortAlphabetical).tag(LibrarySort.alphabetical)
                Text(L.sortDefault).tag(LibrarySort.default)
            }
        }
        if selection.isActive {
            Button(L.t("清除篩選", "Clear filters")) {
                selection.status = .all
                selection.level = "all"
                selection.initial = "all"
            }
        }
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
                    Picker(L.t("題數", "Questions"), selection: Binding(get: { model.settings.quizQuestionCount }, set: { model.settings.quizQuestionCount = $0 })) {
                        ForEach(QuizBuilder.questionCounts, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("quiz-question-count")
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
