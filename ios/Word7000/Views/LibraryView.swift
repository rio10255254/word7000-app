import SwiftUI
import Word7000Core

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    var openBankPicker: () -> Void

    @State private var query = ""
    @State private var filtersOpen = false

    var body: some View {
        let filter = model.settings.libraryFilter
        let results = model.bank.filter(state: model.progress, query: query, filter: filter.status, options: filter.options)

        List {
            Section {
                Picker(L.filterStatus, selection: Binding(
                    get: { model.settings.libraryFilter.status },
                    set: { model.settings.libraryFilter.status = $0 }
                )) {
                    ForEach(LibraryFilter.allCases, id: \.self) { status in
                        Text(L.filterLabel(status)).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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
                Text(L.bankWordCount(results.count))
                    .monospacedDigit()
            }
        }
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(model.bankName)
        .navigationDestination(for: WordEntry.self) { word in
            WordDetailView(word: word)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L.searchPlaceholder)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BankButton(action: openBankPicker)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { filtersOpen = true } label: {
                    Image(systemName: filter.level != "all" || filter.initial != "all" || filter.sort != .default
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(L.filters)
            }
        }
        .sheet(isPresented: $filtersOpen) {
            FilterSheet(selection: Binding(
                get: { model.settings.libraryFilter },
                set: { model.settings.libraryFilter = $0 }
            ), showsSort: true)
            .presentationDetents([.medium, .large])
        }
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(word.word).font(.rounded(.body, weight: .semibold))
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech).font(.caption).foregroundStyle(Palette.accent)
                    }
                }
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
        .padding(.vertical, 2)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Tag(text: word.group)
                        Tag(text: L.statusLabel(progress.status), color: progress.status == .mastered ? Palette.known : progress.status == .review ? Palette.review : .secondary)
                        Spacer()
                        SpeakButton(text: word.word)
                    }
                    Text(word.word)
                        .font(.roundedSize(40, weight: .bold))
                        .textSelection(.enabled)
                    if !word.pronunciation.isEmpty {
                        Text(word.pronunciation).font(.title3).foregroundStyle(.secondary)
                    }
                }
                WordAnswer(word: word)
                if let due = LearningEngine.reviewDueDate(progress), progress.status != .new {
                    Label(L.nextReview(due), systemImage: "calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .card(radius: Metrics.wordCardRadius, padding: 22)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 8)
        }
        .background(Palette.background)
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
