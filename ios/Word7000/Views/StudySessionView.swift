import SwiftUI
import Word7000Core

/// Full-screen flash cards. Tap the card (or the button) to see the answer,
/// then grade it; swiping right or left does the same.
struct StudySessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var startQuiz: () -> Void

    @State private var revealed = false
    @State private var dragOffset: CGFloat = 0
    @State private var feedback = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let session = model.studySession {
                    if session.total == 0 {
                        ContentUnavailableView(L.nothingToStudy, systemImage: "checkmark.seal", description: Text(L.nothingToStudyText))
                    } else if session.isComplete {
                        SessionSummary(session: session, done: { dismiss() }, again: { model.startStudySession() }, startQuiz: startQuiz)
                    } else if let cardId = session.currentCardId, let word = model.word(id: cardId) {
                        SessionBar(fraction: Double(session.done) / Double(max(1, session.total)))
                            .padding(.top, 4)
                        card(word: word)
                        controls
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.close)
                        .accessibilityIdentifier("study-close")
                }
                ToolbarItem(placement: .principal) {
                    if let session = model.studySession, !session.isComplete, session.total > 0 {
                        Text(L.cardCount(done: session.done, total: session.total))
                            .font(.rounded(.subheadline, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.undoStudyGrade() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!model.canUndoStudy)
                        .accessibilityLabel(L.undo)
                        .accessibilityIdentifier("study-undo")
                }
            }
        }
        .onAppear { model.ensureStudySession() }
        .onChange(of: model.studySession?.index) { _, _ in
            revealed = false
            dragOffset = 0
        }
        .sensoryFeedback(.impact(weight: .light), trigger: feedback)
    }

    private func card(word: WordEntry) -> some View {
        let progress = model.progress(for: word.id)
        let face = model.face(word)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Spacer()
                Button { model.toggleFavorite(word.id) } label: {
                    Image(systemName: progress.favorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(progress.favorite ? Palette.review : Palette.tertiaryLabel)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(progress.favorite ? L.unfavoriteWord : L.favoriteWord)
                SpeakButton(text: face.speakText, language: face.speakLanguage)
            }

            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Text(face.prompt)
                    .font(.roundedSize(46, weight: .bold))
                    .minimumScaleFactor(0.4)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                if !face.promptDetail.isEmpty {
                    Text(face.promptDetail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)

            if revealed {
                WordAnswer(word: word)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text(L.tapToReveal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous))
        .overlay(alignment: .top) { swipeBadge }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset) / 28))
        .contentShape(Rectangle())
        .onTapGesture { reveal() }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in dragOffset = value.translation.width }
                .onEnded { value in
                    if abs(value.translation.width) > 110 {
                        grade(value.translation.width > 0 ? .known : .review)
                    } else {
                        withAnimation(.spring) { dragOffset = 0 }
                    }
                }
        )
        .accessibilityIdentifier("study-card")
        .accessibilityAction(named: L.showAnswer) { reveal() }
    }

    @ViewBuilder
    private var swipeBadge: some View {
        if abs(dragOffset) > 30 {
            let known = dragOffset > 0
            Label(known ? L.knowIt : L.dontKnow, systemImage: known ? "checkmark" : "xmark")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(known ? Palette.known : Palette.miss, in: Capsule())
                .padding(.top, 18)
                .opacity(Double(min(1, (abs(dragOffset) - 30) / 60)))
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
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
                Button { reveal() } label: {
                    Text(L.showAnswer).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("study-show-answer")
            }
        }
    }

    private func reveal() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { revealed = true }
    }

    private func grade(_ grade: StudyGrade) {
        feedback += 1
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = grade == .known ? 700 : -700
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            model.gradeCurrentCard(grade)
            dragOffset = 0
            revealed = false
        }
    }
}

/// Meaning, part of speech, other meanings and the example sentence.
struct WordAnswer: View {
    @Environment(AppModel.self) private var model
    var word: WordEntry

    var body: some View {
        let face = model.face(word)
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if !face.answerLabel.isEmpty {
                    Text(face.answerLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                }
                Text(face.answer)
                    .font(.rounded(.title2, weight: .bold))
                if !face.answerDetail.isEmpty {
                    Text(face.answerDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !face.supplemental.isEmpty {
                    Text(face.supplemental)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !face.examplePrimary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(face.examplePrimary)
                    if !face.exampleSecondary.isEmpty {
                        Text(face.exampleSecondary)
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
    var done: () -> Void
    var again: () -> Void
    var startQuiz: () -> Void

    var body: some View {
        let left = max(0, model.progress.dailyTarget - model.progress.studiedToday)
        VStack(spacing: 18) {
            Spacer()
            ProgressRing(fraction: model.dailyFraction, color: model.goalDone ? Palette.known : Palette.accent, lineWidth: 14) {
                Image(systemName: model.goalDone ? "checkmark" : "flame.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(model.goalDone ? Palette.known : Palette.review)
            }
            .frame(width: 130, height: 130)
            Text(L.sessionCompleteTitle)
                .font(.rounded(.title, weight: .bold))
            Text(L.sessionCompleteText(known: session.knownIds.count, review: session.reviewIds.count))
                .foregroundStyle(.secondary)
            Text(left == 0 ? L.sessionGoalDone : L.sessionGoalLeft(left))
                .font(.subheadline.weight(.semibold))
            Spacer()
            VStack(spacing: 12) {
                Button(action: done) {
                    Text(L.done).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("study-done")
                HStack(spacing: 12) {
                    Button(action: again) {
                        Text(L.nextSession).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    Button(action: startQuiz) {
                        Text(L.quickQuiz).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                }
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("study-summary")
    }
}
