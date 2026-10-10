import SwiftUI
import Word7000Core

struct StudyView: View {
    @Environment(AppModel.self) private var model
    var selectTab: (AppTab) -> Void
    var openBankPicker: () -> Void

    @State private var revealed = false
    @State private var dragOffset: CGFloat = 0
    @State private var filtersOpen = false
    @State private var gradeFeedback = 0

    var body: some View {
        VStack(spacing: 12) {
            if let session = model.studySession {
                if session.total == 0 {
                    ContentUnavailableView {
                        Label(L.noStudyWords, systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text(L.relaxFilters)
                    } actions: {
                        Button(L.resetFilters) { model.settings.studyFilter = FilterSelection() }
                    }
                } else if session.isComplete {
                    SessionSummary(session: session, selectTab: selectTab)
                } else if let cardId = session.currentCardId, let word = model.word(id: cardId) {
                    header(session: session)
                    card(word: word)
                    controls(cardId: cardId)
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background)
        .navigationTitle(L.tabStudy)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BankButton(action: openBankPicker)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { filtersOpen = true } label: {
                    Image(systemName: model.settings.studyFilter.isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(L.filters)
                .accessibilityIdentifier("study-filters")
            }
        }
        .sheet(isPresented: $filtersOpen) {
            FilterSheet(selection: Binding(
                get: { model.settings.studyFilter },
                set: { model.settings.studyFilter = $0 }
            ), showsSort: false)
            .presentationDetents([.medium, .large])
        }
        .onAppear { model.ensureStudySession() }
        .onChange(of: model.studySourceKey) { _, _ in model.ensureStudySession() }
        .onChange(of: model.studySession?.index) { _, _ in
            revealed = false
            dragOffset = 0
        }
        .sensoryFeedback(.impact(weight: .light), trigger: gradeFeedback)
    }

    private func header(session: StudySession) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(L.sessionLabel(done: session.done, total: session.total))
                    .font(.rounded(.subheadline, weight: .bold))
                    .monospacedDigit()
                Spacer()
                Text(L.todayGoalLine(model.progress.studiedToday, model.progress.dailyTarget))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            SessionBar(fraction: Double(session.done) / Double(max(1, session.total)))
        }
        .padding(.top, 4)
    }

    private func card(word: WordEntry) -> some View {
        let progress = model.progress(for: word.id)
        return ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Tag(text: word.group)
                    Spacer()
                    Button { model.toggleFavorite(word.id) } label: {
                        Image(systemName: progress.favorite ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(progress.favorite ? Palette.review : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(progress.favorite ? L.unfavoriteWord : L.favoriteWord)
                    SpeakButton(text: word.word)
                }

                Text(word.word)
                    .font(.roundedSize(44, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .padding(.top, 14)
                if !word.pronunciation.isEmpty {
                    Text(word.pronunciation)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                if revealed {
                    WordAnswer(word: word)
                        .padding(.top, 18)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Spacer(minLength: 0)
                    VStack(spacing: 8) {
                        Image(systemName: "eye")
                            .font(.title2)
                        Text(L.tapToReveal)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous))
            .overlay(alignment: .topTrailing) { swipeBadge }
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset) / 30))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { revealed = true }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in dragOffset = value.translation.width }
                .onEnded { value in
                    let distance = value.translation.width
                    if abs(distance) > 110 {
                        grade(distance > 0 ? .known : .review)
                    } else {
                        withAnimation(.spring) { dragOffset = 0 }
                    }
                }
        )
        .accessibilityIdentifier("study-card")
        .accessibilityAction(named: L.showAnswer) { revealed = true }
    }

    @ViewBuilder
    private var swipeBadge: some View {
        if abs(dragOffset) > 30 {
            let known = dragOffset > 0
            Label(known ? L.knowIt : L.dontKnow, systemImage: known ? "checkmark" : "xmark")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(known ? Palette.known : Palette.miss, in: Capsule())
                .padding(18)
                .opacity(min(1, (abs(dragOffset) - 30) / 60))
        }
    }

    private func controls(cardId: String) -> some View {
        HStack(spacing: 10) {
            Button { model.undoStudyGrade() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(width: 30)
            }
            .secondaryAction(tint: .secondary)
            .disabled(!model.canUndoStudy)
            .accessibilityLabel(L.undo)
            .accessibilityIdentifier("study-undo")

            if revealed {
                Button { grade(.review) } label: {
                    Label(L.dontKnow, systemImage: "xmark").font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction(tint: Palette.miss)
                .accessibilityIdentifier("study-grade-review")

                Button { grade(.known) } label: {
                    Label(L.knowIt, systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .accessibilityIdentifier("study-grade-known")
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { revealed = true }
                } label: {
                    Label(L.showAnswer, systemImage: "eye").font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("study-show-answer")
            }
        }
    }

    private func grade(_ grade: StudyGrade) {
        gradeFeedback += 1
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = grade == .known ? 600 : -600
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            model.gradeCurrentCard(grade)
            dragOffset = 0
            revealed = false
        }
    }
}

/// Meaning, supplemental meanings and the example, shown once revealed.
struct WordAnswer: View {
    var word: WordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                if !word.partOfSpeech.isEmpty {
                    Text(word.partOfSpeech)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                }
                Text(word.meaningZh)
                    .font(.rounded(.title2, weight: .bold))
            }
            if let more = word.supplementalMeaningZh, !more.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.supplementalMeanings).font(.caption).foregroundStyle(.secondary)
                    Text(more).font(.body)
                }
            }
            if !word.example.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.example)
                        .font(.body)
                    if !word.exampleZh.isEmpty {
                        Text(word.exampleZh)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SessionSummary: View {
    @Environment(AppModel.self) private var model
    var session: StudySession
    var selectTab: (AppTab) -> Void

    var body: some View {
        let left = max(0, model.progress.dailyTarget - model.progress.studiedToday)
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Palette.review)
                    .frame(width: 72, height: 72)
                    .background(Palette.review.opacity(0.14), in: Circle())
                Text(L.sessionCompleteTitle)
                    .font(.rounded(.title2, weight: .bold))
                Text(L.sessionCompleteText(known: session.knownIds.count, review: session.reviewIds.count))
                    .foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    StatTile(value: model.progress.studiedToday, label: L.todayGoalLine(model.progress.studiedToday, model.progress.dailyTarget))
                    Divider().frame(height: 36)
                    StatTile(value: model.progress.streak, label: L.streak, color: Palette.review)
                }
                .padding(.vertical, 12)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(left == 0 ? L.sessionGoalDone : L.sessionGoalLeft(left))
                    .font(.subheadline.weight(.semibold))

                VStack(spacing: 10) {
                    Button { model.startStudySession() } label: {
                        Label(L.nextSession, systemImage: "book.fill").font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("study-next-session")

                    if !session.reviewIds.isEmpty {
                        Button { model.startStudySession(onlyIds: session.reviewIds) } label: {
                            Label(L.reviewMissed(session.reviewIds.count), systemImage: "arrow.counterclockwise")
                                .font(.headline).frame(maxWidth: .infinity)
                        }
                        .secondaryAction(tint: Palette.review)
                    }

                    Button { selectTab(.quiz) } label: {
                        Label(L.goQuiz, systemImage: "checklist").font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                }
            }
            .card(radius: Metrics.wordCardRadius, padding: 22)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("study-summary")
    }
}
