import SwiftUI
import Word7000Core

/// The word banks as a shelf, and the words of the chosen bank below.
struct WordsView: View {
    @Environment(AppModel.self) private var model
    var scan: () -> Void
    var study: () -> Void

    @State private var query = ""
    @State private var renaming: CustomVocabSet?
    @State private var newName = ""

    var body: some View {
        let filter = model.settings.libraryFilter
        let results = model.bank.filter(state: model.progress, query: query, filter: filter.status, options: filter.options)

        List {
            if query.isEmpty {
                Section {
                    BankShelf(scan: scan, rename: { set in
                        newName = set.name
                        renaming = set
                    })
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(results) { word in
                    NavigationLink(value: word) {
                        WordRow(word: word, progress: model.progress(for: word.id))
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
        .overlay {
            if results.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView(L.noLibraryWords, systemImage: "text.magnifyingglass")
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle(L.tabWords)
        .navigationDestination(for: WordEntry.self) { word in
            WordDetailView(word: word)
        }
        .searchable(text: $query, prompt: L.searchPlaceholder)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
        .alert(L.renameBank, isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(L.bankName, text: $newName)
            Button(L.cancel, role: .cancel) { renaming = nil }
            Button(L.save) {
                if let set = renaming { model.renameSet(set.id, to: newName) }
                renaming = nil
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker(L.filterStatus, selection: binding(\.status)) {
                ForEach(LibraryFilter.allCases, id: \.self) { status in
                    Text(L.filterLabel(status)).tag(status)
                }
            }
            Picker(L.filterSort, selection: binding(\.sort)) {
                Text(L.sortDefault).tag(LibrarySort.default)
                Text(L.sortAlphabetical).tag(LibrarySort.alphabetical)
            }
            Menu(L.filterLevel) {
                Picker(L.filterLevel, selection: binding(\.level)) {
                    Text(L.allLevels).tag("all")
                    ForEach(model.levels, id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
            }
        } label: {
            Image(systemName: model.settings.libraryFilter.isActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(L.filters)
        .accessibilityIdentifier("words-filter")
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
    var scan: () -> Void
    var rename: (CustomVocabSet) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                card(id: WordBanks.coreBankId, name: L.coreBankName, count: model.vocabularyWords.count, icon: "character.book.closed.fill", color: Palette.accent)
                ForEach(model.customSets.sets) { set in
                    let scanned = set.wordIds.contains(where: WordBanks.isScannedWordId)
                    card(id: set.id, name: set.name, count: WordBanks.words(of: set, in: model.allWords).count,
                         icon: scanned ? "doc.text.viewfinder" : "folder.fill", color: Color(hex: set.color) ?? Palette.accent)
                        .contextMenu {
                            Button { rename(set) } label: { Label(L.renameBank, systemImage: "pencil") }
                            Button(role: .destructive) { model.deleteSet(set.id) } label: { Label(L.deleteBank, systemImage: "trash") }
                        }
                }
                Button(action: scan) {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: "plus.viewfinder")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                        Spacer(minLength: 0)
                        Text(L.scanSheet)
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    .padding(14)
                    .frame(width: 128, height: 112, alignment: .leading)
                    .background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("words-scan")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    private func card(id: String, name: String, count: Int, icon: String, color: Color) -> some View {
        let active = model.settings.activeBankId == id
        return Button {
            withAnimation(.snappy) { model.selectBank(id) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(active ? .white : color)
                    Spacer()
                    if active {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    }
                }
                Spacer(minLength: 0)
                Text(name)
                    .font(.rounded(.subheadline, weight: .bold))
                    .lineLimit(2)
                    .foregroundStyle(active ? .white : .primary)
                Text(L.bankWordCount(count))
                    .font(.caption)
                    .foregroundStyle(active ? .white.opacity(0.8) : .secondary)
            }
            .padding(14)
            .frame(width: 128, height: 112, alignment: .leading)
            .background(active ? color : Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

struct WordRow: View {
    var word: WordEntry
    var progress: WordProgress

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityLabel(L.statusLabel(progress.status))
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word).font(.rounded(.body, weight: .semibold))
                Text(word.meaningZh)
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

struct WordDetailView: View {
    @Environment(AppModel.self) private var model
    var word: WordEntry

    var body: some View {
        let progress = model.progress(for: word.id)
        List {
            Section {
                VStack(spacing: 6) {
                    Text(word.word)
                        .font(.roundedSize(42, weight: .bold))
                        .textSelection(.enabled)
                    if !word.pronunciation.isEmpty {
                        Text(word.pronunciation).font(.title3).foregroundStyle(.secondary)
                    }
                    SpeakButton(text: word.word)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                    }
                    Text(word.meaningZh).font(.rounded(.title3, weight: .bold))
                    if let more = word.supplementalMeaningZh, !more.isEmpty {
                        Text(more).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.meaning)
            }
            if !word.example.isEmpty {
                Section(L.example) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.example)
                        if !word.exampleZh.isEmpty {
                            Text(word.exampleZh).font(.subheadline).foregroundStyle(.secondary)
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
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
