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
        Picker(L.filterLevel, selection: $selection.level) {
            Text(L.allLevels).tag("all")
            ForEach(model.levels, id: \.self) { Text($0).tag($0) }
        }
        // English first letters only sort English words.
        if model.studyMode == .english || !ChineseCourse.isAvailable {
            Picker(L.t("英文字首", "English first letter"), selection: $selection.initial) {
                Text(L.t("全部字首", "All letters")).tag("all")
                ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init), id: \.self) { Text($0).tag($0) }
            }
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FilterControls(selection: Binding(get: { model.settings.studyFilter }, set: { model.settings.studyFilter = $0 }))
                } header: { Text(model.bankName) }
                Section {
                    LabeledContent(L.t("符合條件", "Matching words"), value: L.bankWordCount(model.studyCandidates.count))
                }
            }
            .navigationTitle(L.t("學習範圍", "Study scope"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.done) { dismiss() } } }
        }
    }
}

struct QuizConfiguration: View {
    @Environment(AppModel.self) private var model
    var start: () -> Void

    private var selection: Binding<FilterSelection> {
        Binding(get: { model.settings.quizFilter }, set: { model.settings.quizFilter = $0 })
    }

    var body: some View {
        let filter = model.settings.quizFilter
        let count = model.bank.filter(state: model.progress, query: "", filter: filter.status, options: filter.options).count
        Form {
            Section {
                Picker(L.t("題數", "Questions"), selection: Binding(get: { model.settings.quizQuestionCount }, set: { model.settings.quizQuestionCount = $0 })) {
                    ForEach(QuizBuilder.questionCounts, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("quiz-question-count")
            } header: { Text(L.t("這次想練習幾題？", "How many questions?")) }
            Section { FilterControls(selection: selection) } header: { Text(model.bankName) }
            Section {
                LabeledContent(L.t("本輪題數", "This round"), value: "\(min(count, model.settings.quizQuestionCount))")
                Button(action: start) {
                    Text(L.t("開始測驗", "Start quiz")).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(count == 0)
                .accessibilityIdentifier("quiz-start")
            }
        }
        .navigationTitle(L.quickQuiz)
    }
}
