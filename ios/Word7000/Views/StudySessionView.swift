import SwiftUI
import Word7000Core

/// Full-screen flash cards. Tap the card (or the button) to see the answer,
/// then grade it; swiping right or left does the same. The eye toggle in the
/// toolbar skips the tap and opens every card with its answer showing.
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
    /// The next card grows to full size as it takes the top of the stack.
    @State private var cardScale = 1.0
    @State private var armed = false
    @State private var cardWidth: CGFloat = 340
    @State private var lifetime = UUID()
    @State private var visible = true
    /// The daily goal was reached during this visit, not before it.
    @State private var reachedGoalHere = false
    @State private var goalBanner = false

    private enum CardPhase { case idle, dragging, leaving, arriving }
    private var committing: Bool { phase == .leaving || phase == .arriving }
    private var threshold: CGFloat { min(110, cardWidth * 0.28) }
    private var autoReveal: Bool { model.settings.studyAutoReveal ?? false }
    private var showsAnswer: Bool { revealed || autoReveal }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let session = model.studySession {
                    if session.total == 0 {
                        MascotMessage(mood: .cheer, title: L.nothingToStudy, text: L.nothingToStudyText)
                    } else if session.isComplete {
                        SessionSummary(session: session, reachedGoal: reachedGoalHere, done: { dismiss() },
                                       again: { model.startStudySession() }, startQuiz: startQuiz)
                    } else if let cardId = session.currentCardId, let word = model.word(id: cardId) {
                        SessionBar(fraction: Double(session.done) / Double(max(1, session.total)))
                            .padding(.top, 4)
                        GeometryReader { proxy in
                            ZStack {
                                // The next card peeking out underneath, while there is one.
                                // It rises toward the top as the card above is swiped away.
                                if session.total - session.done > 1 {
                                    RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous)
                                        .fill(Palette.surface.opacity(0.55 + 0.3 * dragProgress))
                                        .scaleEffect(x: 0.92 + 0.05 * dragProgress, y: 1, anchor: .bottom)
                                        .offset(y: 9 - 5 * dragProgress)
                                        .accessibilityHidden(true)
                                }
                                card(word: word)
                                    .onAppear {
                                        cardWidth = proxy.size.width
                                        enterCard()
                                        speakIfAutomatic(word)
                                    }
                                    .onChange(of: proxy.size.width) { _, value in cardWidth = value }
                                    .id("\(word.id)-\(session.index)")
                            }
                        }
                        controls
                            .disabled(committing)
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { AmbientBackground(tint: model.goalDone ? Palette.known : Palette.accent) }
            .overlay(alignment: .top) {
                if goalBanner {
                    Label {
                        Text(L.goalReachedBanner)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .symbolEffect(.bounce, value: goalBanner)
                    }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Palette.known, in: Capsule())
                        .padding(.top, 8)
                        .shadow(color: Palette.known.opacity(0.35), radius: 10, y: 4)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .scale(scale: 0.8)).combined(with: .opacity))
                        .accessibilityIdentifier("study-goal-banner")
                }
            }
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Toggle(isOn: Binding(
                        get: { autoReveal },
                        set: { on in withAnimation(reduceMotion ? nil : Motion.reveal) { model.settings.studyAutoReveal = on } }
                    )) {
                        Label(L.autoReveal, systemImage: autoReveal ? "eye" : "eye.slash")
                    }
                    .toggleStyle(.button)
                    .accessibilityHint(L.autoRevealHint)
                    .accessibilityIdentifier("study-auto-reveal")
                    Button { model.undoStudyGrade() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!model.canUndoStudy || committing)
                        .accessibilityLabel(L.undo)
                        .accessibilityIdentifier("study-undo")
                }
            }
        }
        .onAppear { visible = true; model.ensureStudySession() }
        .onDisappear { visible = false; lifetime = UUID(); Speaker.shared.stop(); model.saveNow() }
        .onChange(of: model.studySession?.index) { _, index in
            if !committing { revealed = false; dragOffset = 0; armed = false }
            // A fresh set starts at the first card.
            if index == 0 { reachedGoalHere = false }
        }
        .onChange(of: model.goalDone) { was, now in
            guard !was, now, visible else { return }
            reachedGoalHere = true
            // The summary celebrates on its own when the set ends here.
            guard model.studySession?.isComplete == false else { return }
            withAnimation(reduceMotion ? nil : Motion.pop) { goalBanner = true }
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(reduceMotion ? nil : Motion.reveal) { goalBanner = false }
            }
        }
        .sensoryFeedback(.success, trigger: reachedGoalHere) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback) { _, _ in model.settings.hapticsEnabled ?? true }
        .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55), trigger: revealed) { _, new in new && (model.settings.hapticsEnabled ?? true) }
    }

    /// How far the card has been dragged toward a verdict, 0 to 1.
    private var dragProgress: Double {
        guard phase == .dragging || phase == .leaving else { return 0 }
        return min(1, Double(abs(dragOffset) / max(threshold, 1)))
    }

    private func card(word: WordEntry) -> some View {
        let progress = model.progress(for: word.id)
        let face = model.face(word)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                CardStatusChip(status: progress.status)
                // At accessibility text sizes the level would crowd the buttons.
                if !word.group.isEmpty, !dynamicTypeSize.isAccessibilitySize {
                    Text(word.group)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button { model.toggleFavorite(word.id) } label: {
                    Image(systemName: progress.favorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(progress.favorite ? Palette.review : Palette.tertiaryLabel)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: reduceMotion ? false : progress.favorite)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SoftPressStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: progress.favorite) { _, _ in model.settings.hapticsEnabled ?? true }
                .accessibilityLabel(progress.favorite ? L.unfavoriteWord : L.favoriteWord)
                SpeakButton(text: face.speakText, language: face.speakLanguage)
            }

            GeometryReader { area in
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
                        .padding(.top, showsAnswer ? 18 : 0)
                        .padding(.bottom, 12)

                        if showsAnswer {
                            WordAnswer(word: word)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                    // Before the answer, the word sits in the middle of the card.
                    .frame(minHeight: showsAnswer ? 0 : area.size.height, alignment: showsAnswer ? .top : .center)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(phase == .dragging || committing)
                .overlay(alignment: .bottom) {
                    if !showsAnswer {
                        Label {
                            Text(L.tapToReveal)
                        } icon: {
                            Image(systemName: "hand.tap")
                                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                        }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PremiumSurface(radius: Metrics.wordCardRadius) }
        .overlay {
            // The verdict colours the card as it is dragged toward it.
            RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous)
                .fill((dragOffset > 0 ? Palette.known : Palette.miss).opacity(swipeTint))
                .allowsHitTesting(false)
        }
        // Picked up: the shadow deepens the further the card travels.
        .shadow(color: .black.opacity(0.06 + 0.06 * dragProgress), radius: 12 + 10 * dragProgress, y: 4 + 6 * dragProgress)
        .overlay(alignment: .top) { swipeBadge }
        .scaleEffect(cardScale)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragOffset / max(cardWidth, 1)) * 8), anchor: .bottom)
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

    private var swipeTint: Double {
        guard phase == .dragging || phase == .leaving else { return 0 }
        return min(0.16, Double(abs(dragOffset) / max(threshold, 1)) * 0.12)
    }

    @ViewBuilder
    private var swipeBadge: some View {
        if abs(dragOffset) > 30 {
            let known = dragOffset > 0
            let appear = Double(min(1, (abs(dragOffset) - 30) / 60))
            Label {
                Text(known ? L.knowIt : L.dontKnow)
            } icon: {
                Image(systemName: known ? "checkmark" : "xmark")
                    .symbolEffect(.bounce, value: reduceMotion ? false : armed)
            }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(known ? Palette.known : Palette.miss, in: Capsule())
                .scaleEffect(reduceMotion ? 1 : 0.8 + 0.2 * appear + (armed ? 0.06 : 0))
                .animation(reduceMotion ? nil : Motion.pop, value: armed)
                .padding(.top, 18)
                .opacity(appear)
        }
    }

    private var controls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            if showsAnswer {
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
        guard !committing, phase != .dragging, !showsAnswer else { return }
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
                cardScale = reduceMotion ? 1 : 0.94
                cardOpacity = 0
                revealed = false
                armed = false
                model.gradeCurrentCard(grade, expectedWordId: wordId)
            }
            if model.studySession?.isComplete == true { phase = .idle; cardOpacity = 1; cardScale = 1; dragOffset = 0 }
        }
    }

    /// Reads the front of each new card aloud when the learner turned that on.
    private func speakIfAutomatic(_ word: WordEntry) {
        let preferences = model.settings.speech ?? SpeechPreferences()
        guard preferences.autoSpeak == true, visible else { return }
        let face = model.face(word)
        guard Speaker.shared.activeText != face.speakText else { return }
        Speaker.shared.speak(face.speakText, language: face.speakLanguage, preferences: preferences)
    }

    private func enterCard() {
        guard phase == .arriving else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.card, completionCriteria: .logicallyComplete) {
            cardOpacity = 1
            cardScale = 1
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
    @State private var aiOpen = false

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
            .entrance(0, distance: 8)
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
                .entrance(1, distance: 8)
            }
            if CloudAssistant.shared.offered {
                Button { aiOpen = true } label: {
                    Label(L.t("AI 解說與提問", "AI explanation and questions"), systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.top, 4)
                .entrance(2, distance: 8)
                .accessibilityIdentifier("study-ai")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $aiOpen) { AIWordSheet(word: word) }
    }
}

/// Whether the card is new, still being learned, or a scheduled review.
struct CardStatusChip: View {
    var status: WordStatus

    private var style: (text: String, color: Color) {
        switch status {
        case .new: (L.t("新字", "New"), Palette.accent)
        case .review: (L.t("還不熟", "Still learning"), Palette.review)
        case .mastered: (L.t("複習", "Review"), Palette.known)
        }
    }

    var body: some View {
        Text(style.text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(style.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(style.color.opacity(0.14), in: Capsule())
    }
}

struct SessionSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var session: StudySession
    /// The daily goal was reached during this set.
    var reachedGoal = false
    var done: () -> Void
    var again: () -> Void
    var startQuiz: () -> Void

    var body: some View {
        let left = max(0, model.progress.dailyTarget - model.progress.studiedToday)
        ScrollView {
          VStack(spacing: 18) {
            ProgressRing(fraction: model.dailyFraction, color: model.goalDone ? Palette.known : Palette.accent, lineWidth: 14) {
                // The companion sits in the ring, cheering when the goal is met.
                Mascot(mood: reachedGoal || model.goalDone ? .cheer : .happy, size: 78, hop: appeared ? 1 : 0)
                    .offset(y: 4)
            }
            .frame(width: 130, height: 130)
            .entrance(0)
            Text(reachedGoal ? L.goalReachedTitle : L.sessionCompleteTitle)
                .font(.rounded(.title, weight: .bold))
                .entrance(1)
            Text(L.sessionCompleteText(known: session.knownIds.count, review: session.reviewIds.count))
                .foregroundStyle(.secondary)
                .entrance(2)
            HStack(spacing: 10) {
                SummaryChip(value: session.knownIds.count, label: L.knowIt, icon: "checkmark", tint: Palette.known)
                    .entrance(3)
                SummaryChip(value: session.reviewIds.count, label: L.dontKnow, icon: "arrow.counterclockwise", tint: Palette.review)
                    .entrance(4)
                SummaryChip(value: model.progress.streak, label: L.streak, icon: "flame.fill", tint: Palette.review)
                    .entrance(5)
            }
            .accessibilityElement(children: .contain)
            Text(reachedGoal ? L.quizTodaysWordsHint : left == 0 ? L.sessionGoalDone : L.sessionGoalLeft(left))
                .font(.subheadline.weight(.semibold))
                .entrance(6)
            VStack(spacing: 12) {
                if reachedGoal {
                    Button {
                        model.requestQuizOnTodaysWords()
                        startQuiz()
                    } label: {
                        Text(L.quizTodaysWords).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: Palette.known)
                    .accessibilityIdentifier("study-quiz-today")
                }
                let doneButton = Button(action: done) {
                    Text(L.done).font(.headline).frame(maxWidth: .infinity)
                }
                if reachedGoal {
                    doneButton.secondaryAction().accessibilityIdentifier("study-done")
                } else {
                    doneButton.prominentAction().accessibilityIdentifier("study-done")
                }
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
        .overlay(alignment: .top) {
            if reachedGoal && appeared && !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .onAppear { appeared = true }
        .accessibilityIdentifier("study-summary")
    }
}

/// A number with its label, e.g. "12 · Know it", on the end-of-set screen.
private struct SummaryChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var value: Int
    var label: String
    var icon: String
    var tint: Color
    /// The number rolls up from zero once the chip is on screen.
    @State private var rolled = false

    var body: some View {
        let shown = rolled || reduceMotion ? value : 0
        VStack(spacing: 4) {
            Label("\(shown)", systemImage: icon)
                .font(.rounded(.title3, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(shown)))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .task {
            guard !rolled else { return }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { rolled = true }
        }
    }
}

/// A short shower of paper when the daily goal is reached. Purely decorative.
struct ConfettiBurst: View {
    private struct Piece {
        var x: Double, delay: Double, speed: Double, spin: Double, drift: Double, size: CGSize, color: Color
    }

    private static let colors: [Color] = [Palette.accent, Palette.known, Palette.review, Palette.chinese, Palette.miss]
    @State private var start = Date()
    @State private var finished = false
    private let pieces: [Piece] = (0..<48).map { index in
        var random = SystemRandomNumberGenerator()
        return Piece(x: .random(in: 0...1, using: &random),
                     delay: .random(in: 0...0.5, using: &random),
                     speed: .random(in: 260...420, using: &random),
                     spin: .random(in: -4...4, using: &random),
                     drift: .random(in: -40...40, using: &random),
                     size: CGSize(width: .random(in: 6...10, using: &random), height: .random(in: 10...16, using: &random)),
                     color: colors[index % colors.count])
    }
    private let duration = 2.6

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: finished)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard !finished, elapsed < duration + 0.6 else { return }
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + piece.speed * t + 60 * t * t
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + piece.drift * sin(t * 3)
                    let fade = max(0, min(1, (duration - t) / 0.6))
                    var pieceContext = context
                    pieceContext.opacity = fade
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(piece.spin * t))
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                      width: piece.size.width, height: piece.size.height)
                    pieceContext.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(piece.color))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 600)
        .onAppear { start = Date() }
        .task {
            // Stop redrawing once the last piece has gone.
            try? await Task.sleep(for: .seconds(duration + 0.6))
            finished = true
        }
        .accessibilityHidden(true)
    }
}
