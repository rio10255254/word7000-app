import SwiftUI
import Word7000Core

struct BankManagementView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var setId: String
    @State private var name = ""
    @State private var loaded = false
    @State private var selected = Set<String>()
    @State private var editingWord: WordEntry?
    @State private var addingWord = false
    @State private var removing = false
    @State private var notice: String?

    private var bank: CustomVocabSet? { model.customSets.sets.first { $0.id == setId } }
    private var words: [WordEntry] { WordBanks.words(of: bank, in: model.allWords) }

    var body: some View {
        List {
            Group {
                Section(L.bankName) {
                    TextField(L.bankName, text: $name)
                        .accessibilityIdentifier("bank-name")
                }
                Section {
                    HStack {
                        Text(L.bankWordCount(words.count))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(words.count)))
                        Spacer()
                        Button(selected.count == words.count && !words.isEmpty ? L.t("取消全選", "Deselect all") : L.t("全選", "Select all")) {
                            withAnimation(reduceMotion ? nil : Motion.pop) {
                                selected = selected.count == words.count ? [] : Set(words.map(\.id))
                            }
                        }
                        .disabled(words.isEmpty)
                    }
                    if let notice {
                        Label {
                            Text(notice)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").popIn(delay: 0.1)
                        }
                        .font(.footnote)
                        .foregroundStyle(Palette.known)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }
                    ForEach(words) { word in
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(reduceMotion ? nil : Motion.pop) {
                                    if !selected.insert(word.id).inserted { selected.remove(word.id) }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected.contains(word.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(word.id) ? Palette.accent : Palette.secondaryLabel)
                                        .contentTransition(.symbolEffect(.replace))
                                        .symbolEffect(.bounce, value: reduceMotion ? false : selected.contains(word.id))
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(model.face(word).prompt).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                        Text(model.face(word).answer).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer(minLength: 4)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityAddTraits(selected.contains(word.id) ? .isSelected : [])
                            if model.customSets.customWords.contains(where: { $0.id == word.id }) {
                                Button { editingWord = word } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(L.t("編輯 \(word.word)", "Edit \(word.word)"))
                            }
                        }
                    }
                    if words.isEmpty { Text(L.t("還沒有單字", "No words yet")).foregroundStyle(.secondary) }
                }
            }
            .listRowBackground(Palette.surface)
        }
        .warmList()
        .navigationTitle(L.t("管理單字集", "Manage bank"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.save) {
                    model.renameSet(setId, to: name.trimmed)
                    dismiss()
                }
                .disabled(name.trimmed.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingWord = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L.addWord)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Menu {
                    transferMenu(move: false)
                    transferMenu(move: true)
                } label: { Image(systemName: "folder.badge.plus") }
                .disabled(selected.isEmpty || model.customSets.sets.count < 2)
                .accessibilityLabel(L.t("複製或移動單字", "Copy or move words"))
                Spacer()
                Text(L.t("已選 \(selected.count) 個", "\(selected.count) selected"))
                    .font(.subheadline)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(selected.count)))
                    .animation(reduceMotion ? nil : Motion.reveal, value: selected.count)
                Spacer()
                Button(role: .destructive) { removing = true } label: { Image(systemName: "minus.circle") }
                    .disabled(selected.isEmpty)
                    .accessibilityLabel(L.removeFromBank)
            }
        }
        .onAppear { if !loaded { name = bank?.name ?? ""; loaded = true } }
        .sensoryFeedback(.selection, trigger: selected) { _, _ in model.settings.hapticsEnabled ?? true }
        .sensoryFeedback(.success, trigger: notice) { _, new in new != nil && (model.settings.hapticsEnabled ?? true) }
        .sheet(item: $editingWord) { WordEditorSheet(word: $0, setId: setId) }
        .sheet(isPresented: $addingWord) { WordEditorSheet(setId: setId) }
        .confirmationDialog(L.t("移出 \(selected.count) 個單字？", "Remove \(selected.count) words from this bank?"), isPresented: $removing, titleVisibility: .visible) {
            Button(L.removeFromBank, role: .destructive) {
                withAnimation(reduceMotion ? nil : Motion.card) {
                    model.removeWords(selected, fromSet: setId)
                    selected = []
                }
            }
        } message: {
            Text(L.t("不會刪除這些單字的學習紀錄。", "Their learning records will be kept."))
        }
    }

    private func transferMenu(move: Bool) -> some View {
        Menu(move ? L.t("移至單字集", "Move to bank") : L.t("複製至單字集", "Copy to bank")) {
            ForEach(model.customSets.sets.filter { $0.id != setId }) { target in
                Button(target.name) {
                    let count = selected.count
                    withAnimation(reduceMotion ? nil : Motion.card) {
                        model.transferWords(selected, from: setId, to: target.id, move: move)
                        selected = []
                        notice = L.t("已將 \(count) 個單字加入「\(target.name)」", "Added \(count) words to \(target.name)")
                    }
                }
            }
        }
    }
}

struct WordEditorSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var word: WordEntry?
    var setId: String
    @State private var english: String
    @State private var meaning: String
    @State private var part: String
    @State private var supplemental: String
    @State private var example: String
    @State private var translation: String
    @State private var filling = false
    @State private var fillFailure: CloudAI.Failure?
    @State private var askCloud = false
    /// Bumped when the AI fills the form, for a success tap.
    @State private var filled = 0

    init(word: WordEntry? = nil, setId: String) {
        self.word = word
        self.setId = setId
        _english = State(initialValue: word?.word ?? "")
        _meaning = State(initialValue: word?.meaningZh ?? "")
        _part = State(initialValue: word?.partOfSpeech ?? "")
        _supplemental = State(initialValue: word?.supplementalMeaningZh ?? "")
        _example = State(initialValue: word?.example ?? "")
        _translation = State(initialValue: word?.exampleZh ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        TextField("English", text: $english).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField(L.t("主要意思", "Main meaning"), text: $meaning, axis: .vertical)
                        TextField(L.t("詞性", "Part of speech"), text: $part).textInputAutocapitalization(.never)
                        TextField(L.t("補充意思", "Other meanings"), text: $supplemental, axis: .vertical)
                        if CloudAssistant.shared.offered {
                            Button(action: fill) {
                                HStack {
                                    Label {
                                        Text(L.t("AI 幫我填意思、詞性和例句", "AI fill-in: meaning, part of speech and example"))
                                    } icon: {
                                        Image(systemName: "sparkles")
                                            .symbolEffect(.pulse, options: .repeating, isActive: filling && !reduceMotion)
                                    }
                                    if filling { Spacer(); ProgressView() }
                                }
                            }
                            .disabled(english.trimmed.isEmpty || filling)
                            .accessibilityIdentifier("word-editor-ai-fill")
                            if let fillFailure { Text(fillFailure.message).font(.footnote).foregroundStyle(.secondary) }
                        }
                    } footer: {
                        if CloudAssistant.shared.offered {
                            Text(L.t("AI 只會填入空白的欄位，存入前請再確認。", "AI fills only empty fields; check them before saving."))
                        }
                    }
                    Section(L.t("例句（選填）", "Example (optional)")) {
                        TextField(L.t("英文例句", "English example"), text: $example, axis: .vertical).lineLimit(2...6)
                        TextField(L.t("中文翻譯", "Chinese translation"), text: $translation, axis: .vertical).lineLimit(2...6)
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .warmList()
            .scrollDismissesKeyboard(.interactively)
            .cloudConsentAlert(isPresented: $askCloud) { if IntelligenceSettings.shared.cloudConsent == true { fill() } }
            .sensoryFeedback(.success, trigger: filled) { _, _ in model.settings.hapticsEnabled ?? true }
            .navigationTitle(word == nil ? L.addWord : L.t("編輯單字", "Edit word"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save, action: save)
                        .disabled(english.trimmed.isEmpty || meaning.trimmed.isEmpty)
                        .accessibilityIdentifier("word-editor-save")
                }
            }
        }
    }

    /// Suggests the fields the learner left empty; what they typed stays.
    private func fill() {
        let text = english.trimmed
        guard !text.isEmpty, !filling else { return }
        if CloudAssistant.shared.needsConsent { askCloud = true; return }
        filling = true
        fillFailure = nil
        Task {
            defer { filling = false }
            do {
                let suggestion = try await CloudAssistant.shared.run(.fillWord, ["word": .string(String(text.prefix(80)))], as: CloudAI.WordSuggestion.self).cleaned()
                guard english.trimmed == text else { return }
                guard !suggestion.meaning.isEmpty else { fillFailure = .invalidInput; return }
                withAnimation(reduceMotion ? nil : Motion.reveal) {
                    if meaning.trimmed.isEmpty { meaning = suggestion.meaning }
                    if part.trimmed.isEmpty { part = suggestion.partOfSpeech }
                    if supplemental.trimmed.isEmpty { supplemental = suggestion.otherMeanings }
                    if example.trimmed.isEmpty { example = suggestion.example }
                    if translation.trimmed.isEmpty { translation = suggestion.exampleTranslation }
                }
                filled += 1
            } catch is CancellationError {
            } catch {
                fillFailure = (error as? CloudAI.Failure) ?? .unavailable
            }
        }
    }

    private func save() {
        let id = word?.id ?? model.addCustomWord(word: english, partOfSpeech: part, meaning: meaning, toSet: setId)
        guard var entry = model.customSets.customWords.first(where: { $0.id == id }) else { return }
        entry.word = english.trimmed
        entry.meaningZh = meaning.trimmed
        entry.partOfSpeech = part.trimmed
        entry.supplementalMeaningZh = supplemental.trimmed
        entry.example = example.trimmed
        entry.exampleZh = translation.trimmed
        model.editCustomWord(entry)
        dismiss()
    }
}
