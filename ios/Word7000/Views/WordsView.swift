import SwiftUI
import Word7000Core

/// The word banks as a shelf, and the words of the chosen bank below.
struct WordsView: View {
    @Environment(AppModel.self) private var model
    var scan: () -> Void
    var study: () -> Void

    @State private var query = ""
    private enum BankNameAction { case create, rename(String) }
    @State private var bankNameAction: BankNameAction?
    @State private var managingID: String?
    @State private var filtersOpen = false
    @State private var results: [WordEntry] = []
    @State private var searching = true
    @State private var newName = ""
    @State private var addingWord = false

    var body: some View {
        let filter = model.settings.libraryFilter

        List {
            if query.isEmpty {
                Section {
                    BankShelf(scan: scan, manage: { managingID = $0.id }, rename: {
                        newName = $0.name
                        bankNameAction = .rename($0.id)
                    })
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                if filter.isActive {
                    HStack(alignment: .top) {
                        Text(filterSummary).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(L.t("清除", "Clear")) { clearFilters() }.font(.caption.weight(.semibold))
                    }
                }
                if results.isEmpty {
                    if searching {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 30)
                    } else {
                        ContentUnavailableView(L.noLibraryWords, systemImage: "text.magnifyingglass",
                                               description: Text(query.isEmpty ? model.bankName : query))
                        if filter.isActive {
                            Button(L.t("清除篩選", "Clear filters")) { clearFilters() }
                        } else if model.activeSet != nil, query.isEmpty {
                            Button(L.addWord) { addingWord = true }
                        }
                    }
                }
                ForEach(results) { word in
                    NavigationLink(value: word) {
                        WordRow(word: word, progress: model.progress(for: word.id), query: query)
                    }
                    .swipeActions(edge: .trailing) {
                        let favorite = model.progress(for: word.id).favorite
                        Button { model.toggleFavorite(word.id) } label: {
                            Label(favorite ? L.unfavoriteWord : L.favoriteWord, systemImage: favorite ? "star.slash" : "star.fill")
                        }
                        .tint(Palette.review)
                    }
                }
            } header: {
                HStack {
                    Text(filter.status == .all ? model.bankName : "\(model.bankName) · \(L.filterLabel(filter.status))")
                    Spacer()
                    Text(L.bankWordCount(results.count)).monospacedDigit()
                }
            }
        }
        .navigationTitle(L.tabWords)
        .navigationDestination(for: WordEntry.self) { word in
            WordDetailView(word: word)
        }
        .navigationDestination(item: $managingID) { BankManagementView(setId: $0) }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L.searchPlaceholder)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.settings.activeBankId) { _, _ in query = "" }
        .task(id: SearchKey(query: query, bank: model.settings.activeBankId, filter: filter, revision: model.libraryRevision)) {
            await refreshResults()
        }
        .safeAreaInset(edge: .bottom) {
            if let deleted = model.deletedSetUndo {
                HStack {
                    Text(L.t("已刪除「\(deleted.name)」", "Deleted \(deleted.name)")).font(.subheadline).lineLimit(2)
                    Spacer()
                    Button(L.undo) { model.restoreDeletedSet() }.fontWeight(.semibold)
                        .accessibilityIdentifier("bank-undo-delete")
                    Button { model.dismissDeletedSetUndo() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel(L.close)
                }
                .padding(.horizontal, 16)
                .background(.regularMaterial)
            }
        }
        .sheet(isPresented: $filtersOpen) {
            NavigationStack {
                Form {
                    Section {
                        FilterControls(selection: Binding(get: { model.settings.libraryFilter }, set: { model.settings.libraryFilter = $0 }), includesSort: true)
                    }
                }
                .navigationTitle(L.filters)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.done) { filtersOpen = false } } }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: scan) { Label(L.scanSheet, systemImage: "doc.text.viewfinder") }
                    Button {
                        newName = ""
                        bankNameAction = .create
                    } label: { Label(L.newBank, systemImage: "folder.badge.plus") }
                    .accessibilityIdentifier("words-new-bank")
                    if model.activeSet != nil {
                        Button { addingWord = true } label: { Label(L.addWord, systemImage: "plus") }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("words-add")
            }
        }
        .sheet(isPresented: $addingWord) {
            AddWordSheet()
        }
        .alert(bankNameTitle, isPresented: Binding(get: { bankNameAction != nil }, set: { if !$0 { bankNameAction = nil } }), presenting: bankNameAction) { action in
            TextField(L.bankName, text: $newName).accessibilityIdentifier("bank-name-input")
            Button(L.cancel, role: .cancel) { bankNameAction = nil }
            Button(L.save) {
                switch action {
                case .create:
                    let id = model.createSet(named: newName)
                    model.selectBank(id)
                case let .rename(id):
                    model.renameSet(id, to: newName)
                }
                bankNameAction = nil
            }
            .disabled(newName.trimmed.isEmpty)
        }
    }

    private var bankNameTitle: String {
        guard let action = bankNameAction else { return L.newBank }
        switch action {
        case .create: return L.newBank
        case .rename: return L.renameBank
        }
    }

    private var filterMenu: some View {
        Button { filtersOpen = true } label: {
            Image(systemName: model.settings.libraryFilter.isActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(L.filters)
        .accessibilityIdentifier("words-filter")
    }

    private struct SearchKey: Equatable {
        var query: String
        var bank: String
        var filter: FilterSelection
        var revision: Int
    }

    @MainActor private func refreshResults() async {
        searching = true
        if !query.trimmed.isEmpty {
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
        }
        let vocabulary = model.bank, state = model.progress, filter = model.settings.libraryFilter, text = query
        let matches = await Task.detached(priority: .userInitiated) {
            vocabulary.filter(state: state, query: text, filter: filter.status, options: filter.options, rankedSearch: true)
        }.value
        guard !Task.isCancelled else { return }
        if results != matches { results = matches }
        searching = false
    }

    private var filterSummary: String {
        let filter = model.settings.libraryFilter
        return [filter.status == .all ? nil : L.filterLabel(filter.status),
                filter.level == "all" ? nil : filter.level,
                filter.initial == "all" ? nil : "\(L.t("字首", "Letter")) \(filter.initial)"]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func clearFilters() {
        model.settings.libraryFilter.status = .all
        model.settings.libraryFilter.level = "all"
        model.settings.libraryFilter.initial = "all"
    }

    private func binding<T>(_ keyPath: WritableKeyPath<FilterSelection, T>) -> Binding<T> {
        Binding(
            get: { model.settings.libraryFilter[keyPath: keyPath] },
            set: { model.settings.libraryFilter[keyPath: keyPath] = $0 }
        )
    }
}

/// Horizontally scrolling banks; the last card scans a new sheet.
struct BankShelf: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scan: () -> Void
    var manage: (CustomVocabSet) -> Void
    var rename: (CustomVocabSet) -> Void
    @State private var deleting: CustomVocabSet?
    @ScaledMetric(relativeTo: .body) private var shelfWidth = 140.0
    @ScaledMetric(relativeTo: .body) private var shelfHeight = 124.0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                card(id: WordBanks.coreBankId, name: L.coreBankName, count: model.vocabularyWords.count, icon: "character.book.closed.fill", color: Palette.accent)
                ForEach(model.customSets.sets) { set in
                    let scanned = set.wordIds.contains(where: WordBanks.isScannedWordId)
                    card(id: set.id, name: set.name, count: WordBanks.words(of: set, in: model.allWords).count,
                         icon: scanned ? "doc.text.viewfinder" : "folder.fill", color: Color(hex: set.color) ?? Palette.accent)
                        .overlay(alignment: .topTrailing) {
                            Button { manage(set) } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(model.settings.activeBankId == set.id ? .white : Palette.accent)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(SoftPressStyle())
                            .accessibilityLabel(L.t("管理 \(set.name)", "Manage \(set.name)"))
                        }
                        .contextMenu {
                            Button { manage(set) } label: { Label(L.t("管理", "Manage"), systemImage: "slider.horizontal.3") }
                            Button { rename(set) } label: { Label(L.renameBank, systemImage: "pencil") }
                            Button(role: .destructive) { deleting = set } label: { Label(L.deleteBank, systemImage: "trash") }
                                .accessibilityIdentifier("bank-delete")
                        }
                }
                Button(action: scan) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            Image(systemName: "plus.viewfinder")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                            Spacer(minLength: 0)
                            scanAllowance
                        }
                        Spacer(minLength: 0)
                        Text(L.scanSheet)
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    .padding(14)
                    .frame(width: shelfWidth, height: shelfHeight, alignment: .leading)
                    .background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityIdentifier("words-scan")
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 4)
        }
        .confirmationDialog(L.t("刪除「\(deleting?.name ?? "")」？", "Delete \u{201C}\(deleting?.name ?? "")\u{201D}?"),
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button(L.deleteBank, role: .destructive) {
                if let set = deleting { model.deleteSet(set.id) }
                deleting = nil
            }
            .accessibilityIdentifier("bank-delete-confirm")
            Button(L.cancel, role: .cancel) { deleting = nil }
        } message: {
            Text(L.t("學習紀錄會保留，刪除後可按「復原」找回字庫。", "Learning records are kept. You can undo this deletion in the word library."))
        }
    }

    /// Trial scans left, or the Plus badge once scanning is locked.
    @ViewBuilder
    private var scanAllowance: some View {
        switch plus.decide(.scan) {
        case .allowed:
            if case .trial = plus.access {
                Text("\(plus.policy.trialScansLeft)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Palette.accent.opacity(0.16), in: Circle())
                    .accessibilityLabel(P.scansLeft(plus.policy.trialScansLeft))
            }
        case .needsPlus, .trialLimitReached:
            PlusBadge()
        }
    }

    private func card(id: String, name: String, count: Int, icon: String, color: Color) -> some View {
        let active = model.settings.activeBankId == id
        return Button {
            withAnimation(reduceMotion ? nil : Motion.reveal) { model.selectBank(id) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(active ? .white : color)
                    Spacer()
                }
                Spacer(minLength: 0)
                Text(name)
                    .font(.rounded(.subheadline, weight: .bold))
                    .lineLimit(2)
                    .foregroundStyle(active ? .white : .primary)
                HStack {
                    Text(L.bankWordCount(count)).font(.caption)
                        .foregroundStyle(active ? .white.opacity(0.9) : .secondary)
                    Spacer(minLength: 4)
                    if active { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white) }
                }
            }
            .padding(14)
            .frame(width: shelfWidth, height: shelfHeight, alignment: .leading)
            .background(active ? color : Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("bank-\(id)")
    }
}

struct WordRow: View {
    @Environment(AppModel.self) private var model
    var word: WordEntry
    var progress: WordProgress
    var query = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: progress.status == .mastered ? "checkmark.circle.fill" : progress.status == .review ? "arrow.counterclockwise" : "circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(progress.status == .new ? Palette.tertiaryLabel : color)
                .frame(width: 16)
                .accessibilityLabel(L.statusLabel(progress.status))
            VStack(alignment: .leading, spacing: 2) {
                let face = model.face(word)
                SearchHighlightedText(text: face.prompt, query: query).font(.rounded(.body, weight: .semibold))
                SearchHighlightedText(text: face.answer, query: query)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if progress.favorite {
                Image(systemName: "star.fill").font(.caption).foregroundStyle(Palette.review)
            }
        }
    }

    private var color: Color {
        switch progress.status {
        case .new: Palette.fill
        case .review: Palette.review
        case .mastered: Palette.known
        }
    }
}

struct SearchHighlightedText: View {
    var text: String
    var query: String

    var body: some View {
        var attributed = AttributedString(text)
        for term in query.split(whereSeparator: { $0.isWhitespace }) {
            if let range = attributed.range(of: String(term), options: [.caseInsensitive, .diacriticInsensitive]) {
                attributed[range].foregroundColor = Palette.accent
            }
        }
        return Text(attributed)
    }
}

struct WordDetailView: View {
    @Environment(AppModel.self) private var model
    var word: WordEntry
    @State private var editing = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38.0

    var body: some View {
        let word = model.customSets.customWords.first { $0.id == self.word.id } ?? self.word
        let progress = model.progress(for: word.id)
        let face = model.face(word)
        List {
            Section {
                VStack(spacing: 6) {
                    Text(face.prompt)
                        .font(.roundedSize(titleSize, weight: .bold))
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    if !face.promptDetail.isEmpty {
                        Text(face.promptDetail).font(.title3).foregroundStyle(.secondary)
                    }
                    SpeakButton(text: face.speakText, language: face.speakLanguage)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if !face.answerLabel.isEmpty {
                        Text(face.answerLabel).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                    }
                    Text(face.answer).font(.rounded(.title3, weight: .bold))
                    if !face.answerDetail.isEmpty {
                        Text(face.answerDetail).foregroundStyle(.secondary)
                    }
                    if !face.supplemental.isEmpty {
                        Text(face.supplemental).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.meaning)
            }
            if !face.examplePrimary.isEmpty {
                Section(L.example) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(face.examplePrimary)
                        if !face.exampleSecondary.isEmpty {
                            Text(face.exampleSecondary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                LabeledContent(L.status, value: L.statusLabel(progress.status))
                if progress.status != .new, let due = LearningEngine.reviewDueDate(progress) {
                    LabeledContent(L.nextReviewTitle, value: due)
                }
                LabeledContent(L.level, value: word.group)
            }
        }
        .navigationTitle(face.prompt)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Speaker.shared.stop() }
        .sheet(isPresented: $editing) {
            WordEditorSheet(word: word, setId: model.customSets.sets.first { $0.wordIds.contains(word.id) }?.id ?? model.settings.activeBankId)
        }
        .toolbar {
            if model.customSets.customWords.contains(where: { $0.id == word.id }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel(L.t("編輯單字", "Edit word"))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(model.customSets.sets) { set in
                        Button {
                            model.addWord(word.id, toSet: set.id)
                        } label: {
                            Label(set.name, systemImage: set.wordIds.contains(word.id) ? "checkmark" : "folder")
                        }
                        .disabled(set.wordIds.contains(word.id))
                    }
                    Button {
                        let id = model.createSet(named: L.newBankDefault)
                        model.addWord(word.id, toSet: id)
                    } label: {
                        Label(L.newBank, systemImage: "folder.badge.plus")
                    }
                    if let active = model.activeSet, active.wordIds.contains(word.id) {
                        Divider()
                        Button(role: .destructive) {
                            model.removeWord(word.id, fromSet: active.id)
                        } label: {
                            Label(L.removeFromBank, systemImage: "minus.circle")
                        }
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel(L.addToBank)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.toggleFavorite(word.id) } label: {
                    Image(systemName: progress.favorite ? "star.fill" : "star")
                }
                .tint(Palette.review)
                .accessibilityLabel(progress.favorite ? L.unfavoriteWord : L.favoriteWord)
            }
        }
    }
}

/// Type a word and its meaning into the current bank.
struct AddWordSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        WordEditorSheet(setId: model.settings.activeBankId)
    }
}
