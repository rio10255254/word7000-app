import SwiftUI
import Word7000Core

/// Full-screen flash cards. Tap the card (or the button) to see the answer,
/// then grade it; swiping right or left does the same.
struct StudySessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var promptSize = 42.0
    var startQuiz: () -> Void

    @State private var revealed = false
    @State private var dragOffset: CGFloat = 0
    @State private var feedback = 0
    @State private var phase: CardPhase = .idle
    @State private var cardOpacity = 1.0
    @State private var armed = false
    @State private var cardWidth: CGFloat = 340
    @State private var lifetime = UUID()
    @State private var visible = true

    private enum CardPhase { case idle, dragging, leaving, arriving }
    private var committing: Bool { phase == .leaving || phase == .arriving }
    private var threshold: CGFloat { min(110, cardWidth * 0.28) }

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
                        GeometryReader { proxy in
                            card(word: word)
                                .onAppear {
                                    cardWidth = proxy.size.width
                                    enterCard()
                                }
                                .onChange(of: proxy.size.width) { _, value in cardWidth = value }
                                .id("\(word.id)-\(session.index)")
                        }
                        controls
                            .disabled(committing)
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
                            .accessibilityIdentifier("study-position")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.undoStudyGrade() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!model.canUndoStudy || committing)
                        .accessibilityLabel(L.undo)
                        .accessibilityIdentifier("study-undo")
                }
            }
        }
        .onAppear { visible = true; model.ensureStudySession() }
        .onDisappear { visible = false; lifetime = UUID(); Speaker.shared.stop(); model.saveNow() }
        .onChange(of: model.studySession?.index) { _, _ in
            if !committing { revealed = false; dragOffset = 0; armed = false }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback) { _, _ in model.settings.hapticsEnabled ?? true }
        .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new && (model.settings.hapticsEnabled ?? true) }
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
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(progress.favorite ? L.unfavoriteWord : L.favoriteWord)
                SpeakButton(text: face.speakText, language: face.speakLanguage)
            }

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Text(face.prompt)
                            .font(.roundedSize(promptSize, weight: .bold))
                            .minimumScaleFactor(0.6)
                            .lineLimit(4)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("study-prompt")
                        if !face.promptDetail.isEmpty {
                            Text(face.promptDetail).font(.title3).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, revealed ? 18 : 52)
                    .padding(.bottom, 12)

                    if revealed {
                        WordAnswer(word: word)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                    } else {
                        Text(L.tapToReveal).font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(phase == .dragging || committing)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous))
        .overlay(alignment: .top) { swipeBadge }
        .offset(x: dragOffset)
        .opacity(cardOpacity)
        .contentShape(Rectangle())
        .onTapGesture { reveal() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard !committing else { return }
                    guard phase == .dragging || abs(value.translation.width) > abs(value.translation.height) * 1.25 else { return }
                    phase = .dragging
                    dragOffset = value.translation.width
                    armed = abs(dragOffset) >= threshold
                }
                .onEnded { value in
                    guard phase == .dragging else { return }
                    let fast = abs(value.translation.width) > 30 && abs(value.predictedEndTranslation.width) > threshold * 1.5
                    if armed || fast {
                        grade(value.translation.width > 0 ? .known : .review)
                    } else {
                        armed = false
                        phase = .idle
                        withAnimation(reduceMotion ? nil : Motion.card) { dragOffset = 0 }
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
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
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
        guard !committing, phase != .dragging, !revealed else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { revealed = true }
    }

    private func grade(_ grade: StudyGrade) {
        guard !committing, let wordId = model.studySession?.currentCardId else { return }
        let token = lifetime
        let source = model.studySession?.sourceKey
        if !armed { feedback += 1 }
        phase = .leaving
        Speaker.shared.stop()
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeIn(duration: 0.25), completionCriteria: .removed) {
            if reduceMotion { cardOpacity = 0 } else { dragOffset = (grade == .known ? 1 : -1) * (cardWidth + 60) }
        } completion: {
            guard visible, token == lifetime, model.studySession?.sourceKey == source,
                  model.studySession?.currentCardId == wordId else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                phase = .arriving
                dragOffset = reduceMotion ? 0 : 18
                cardOpacity = 0
                revealed = false
                armed = false
                model.gradeCurrentCard(grade, expectedWordId: wordId)
            }
            if model.studySession?.isComplete == true { phase = .idle; cardOpacity = 1; dragOffset = 0 }
        }
    }

    private func enterCard() {
        guard phase == .arriving else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.card, completionCriteria: .logicallyComplete) {
            cardOpacity = 1
            dragOffset = 0
        } completion: {
            if visible { phase = .idle }
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
                    HStack {
                        Text(L.example).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        SpeakButton(text: face.examplePrimary, language: face.speakLanguage)
                    }
                    Text(face.examplePrimary).lineSpacing(4)
                    if !face.exampleSecondary.isEmpty {
                        Text(face.exampleSecondary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SessionSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var session: StudySession
    var done: () -> Void
    var again: () -> Void
    var startQuiz: () -> Void

    var body: some View {
        let left = max(0, model.progress.dailyTarget - model.progress.studiedToday)
        ScrollView {
          VStack(spacing: 18) {
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
            VStack(spacing: 12) {
                Button(action: done) {
                    Text(L.done).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("study-done")
                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
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
            .padding(.top, 16)
          }
          .padding(.vertical, 24)
        }
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("study-summary")
    }
}
