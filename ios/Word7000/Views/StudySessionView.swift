import SwiftUI
import Word7000Core

/// Full-screen flash cards. Tap the card (or the button) to see the answer,
/// then grade it; swiping right or left does the same. The eye toggle in the
/// toolbar skips the tap and opens every card with its answer showing.
struct StudySessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(\.appStyle) private var appStyle
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
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
    /// How the companion on the progress bar feels about the last card.
    @State private var buddyMood: Mascot.Mood = .thinking
    @State private var buddyHop = 0
    @State private var buddyRemark: String?
    /// Where the cat's lines come from this session (gathered once).
    @State private var catLines = CatLineSource.none
    /// A word that has now slipped three times or more, with how to remember it.
    @State private var stuck: (word: WordEntry, misses: Int)?
    /// When the card just swiped comes back (明天見, 3 天後見), shown for a
    /// moment so the spacing of reviews can be seen; `comeBackTick` restarts it.
    @State private var comeBack: (text: String, known: Bool)?
    @State private var comeBackTick = 0

    private enum CardPhase { case idle, dragging, leaving, arriving }
    private var committing: Bool { phase == .leaving || phase == .arriving }
    private var threshold: CGFloat { min(110, cardWidth * 0.28) }
    private var autoReveal: Bool { model.settings.studyAutoReveal ?? false }
    /// Learning Chinese, the pinyin can wait for the answer, to practise
    /// reading the characters; learning English, the pronunciation always shows.
    private var pinyinFirst: Bool { model.studyMode != .chinese || (model.settings.studyShowPinyin ?? true) }
    private var showsAnswer: Bool { revealed || autoReveal }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let session = model.studySession {
                    if session.total == 0 {
                        MascotMessage(mood: .cheer, title: L.nothingToStudy, text: L.nothingToStudyText)
                    } else if session.isComplete {
                        // WordCat Next: today's words go on to spot checks
                        // before the summary.
                        if let routine = model.activeRoutine, routine.step != .done {
                            RoutineChecksView(routine: routine)
                        } else if let routine = model.activeRoutine {
                            RoutineSummaryView(routine: routine, reachedGoal: reachedGoalHere, done: { dismiss() },
                                               again: { model.startStudySession() })
                        } else {
                            SessionSummary(session: session, reachedGoal: reachedGoalHere, done: { dismiss() },
                                           again: { model.startStudySession() }, startQuiz: startQuiz)
                        }
                    } else if let cardId = session.currentCardId, let word = model.word(id: cardId) {
                        if let routine = model.activeRoutine {
                            // One bar: the routine's steps, the cat riding the cards' part.
                            RoutineStepStrip(routine: routine, flipped: (session.done, session.total),
                                             rider: .init(mood: buddyMood, hop: buddyHop, remark: buddyRemark))
                        } else {
                            BuddyProgressBar(fraction: Double(session.done) / Double(max(1, session.total)),
                                             mood: buddyMood, hop: buddyHop, remark: buddyRemark)
                        }
                        GeometryReader { proxy in
                            ZStack {
                                // The next card peeking out underneath, while there is one.
                                // It rises toward the top as the card above is swiped away.
                                if session.total - session.done > 1 {
                                    Group {
                                        if appStyle == .collage {
                                            // Collage: a sheet of graph paper under the index card.
                                            PaperSurface(kind: .graph).rotationEffect(.degrees(2.2 - 1.5 * dragProgress))
                                        } else {
                                            RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous)
                                                .fill(Palette.surface.opacity(0.55 + 0.3 * dragProgress))
                                        }
                                    }
                                    .scaleEffect(x: 0.92 + 0.05 * dragProgress, y: 1, anchor: .bottom)
                                    .offset(y: 9 - 5 * dragProgress)
                                    .accessibilityHidden(true)
                                }
                                card(word: word)
                                    .onAppear {
                                        cardWidth = proxy.size.width
                                        enterCard()
                                        speakIfAutomatic(word)
                                        if session.done == 0 { showHowToSwipe() }
                                    }
                                    .onChange(of: proxy.size.width) { _, value in cardWidth = value }
                                    .id("\(word.id)-\(session.index)")
                            }
                            .overlay(alignment: .bottom) {
                                if let comeBack {
                                    Label(comeBack.text, systemImage: comeBack.known ? "calendar" : "arrow.counterclockwise")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(comeBack.known ? Palette.known : Palette.review)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Palette.surface, in: Capsule())
                                        .overlay(Capsule().strokeBorder((comeBack.known ? Palette.known : Palette.review).opacity(0.45), lineWidth: 1.5))
                                        .padding(.bottom, 12)
                                        .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
                                        .allowsHitTesting(false)
                                        .accessibilityIdentifier("study-comes-back")
                                }
                            }
                            .task(id: comeBackTick) {
                                guard comeBackTick > 0 else { return }
                                try? await Task.sleep(for: .seconds(1.4))
                                guard !Task.isCancelled else { return }
                                withAnimation(reduceMotion ? nil : Motion.reveal) { comeBack = nil }
                            }
                        }
                        if let stuck {
                            StuckWordTip(word: stuck.word, misses: stuck.misses) {
                                withAnimation(reduceMotion ? nil : Motion.reveal) { self.stuck = nil }
                            }
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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
            // No set to show (the data was swapped underneath, e.g. a sign-in):
            // close instead of leaving an empty page.
            .task(id: model.studySession == nil) {
                guard model.studySession == nil else { return }
                try? await Task.sleep(for: .milliseconds(400))
                if model.studySession == nil { dismiss() }
            }
            .overlay(alignment: .top) {
                if goalBanner {
                    Label {
                        Text(L.goalReachedBanner)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .symbolEffect(.bounce, value: goalBanner)
                    }
                        .font(.headline)
                        .foregroundStyle(Palette.surface)
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
                        VStack(spacing: 0) {
                            // Today's words count their cards on the step strip instead.
                            if model.activeRoutine == nil {
                                Text(L.cardCount(done: session.done, total: session.total))
                                    .font(.display(.subheadline, weight: .semibold))
                                    .monospacedDigit()
                                    .accessibilityIdentifier("study-position")
                            }
                            // A guest is reminded, quietly, that none of this is kept.
                            if account.configured, !account.isPermanent {
                                Text(L.t("訪客 · 不會保存", "Guest · not kept"))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.review)
                                    .accessibilityIdentifier("study-guest")
                            }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                  // The spot checks and their summary have no cards to show or undo.
                  if !(model.studySession?.isComplete == true && model.activeRoutine != nil) {
                    if model.studyMode == .chinese {
                        // Three small icons fit beside the count on every
                        // iPhone; the labels stay for VoiceOver.
                        Toggle(isOn: Binding(
                            get: { pinyinFirst },
                            set: { on in withAnimation(reduceMotion ? nil : Motion.reveal) { model.settings.studyShowPinyin = on } }
                        )) {
                            Label(L.showPinyin, systemImage: "character.phonetic")
                        }
                        .toggleStyle(.button)
                        .accessibilityHint(L.showPinyinHint)
                        .accessibilityIdentifier("study-pinyin")
                    }
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
        }
        .onAppear {
            visible = true
            model.ensureStudySession()
            catLines = model.catLines
            // Screenshot tests: the tip that turns up on a word's third slip.
            if AppRuntime.catShowcase, stuck == nil, let id = model.studySession?.currentCardId, let word = model.word(id: id) {
                stuck = (word, 3)
            }
        }
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
        .catTip(.study, at: .top)
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
                    Text(L.levelName(word.group))
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
                                .font(.displaySize(promptSize, weight: .bold))
                                .minimumScaleFactor(0.6)
                                .lineLimit(4)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("study-prompt")
                            if !face.promptDetail.isEmpty, pinyinFirst || showsAnswer {
                                Text(face.promptDetail).font(.title3).foregroundStyle(.secondary)
                                    .transition(.opacity)
                                    .accessibilityIdentifier("study-pinyin-text")
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
        // Collage: keep the words clear of the index card's red margin.
        .padding(.leading, appStyle == .collage ? 16 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if appStyle == .collage {
                // Collage: a ruled index card with a red margin, taped on.
                PaperSurface(kind: .ruled)
                    .overlay { Rectangle().strokeBorder(Collage.ink.opacity(0.12), lineWidth: 1) }
            } else {
                PremiumSurface(radius: Metrics.wordCardRadius)
            }
        }
        .overlay(alignment: .top) {
            if appStyle == .collage { TapeStrip(width: 74, angle: 3).offset(y: -10) }
        }
        .overlay {
            // The verdict colours the card as it is dragged toward it.
            RoundedRectangle(cornerRadius: appStyle == .collage ? 0 : Metrics.wordCardRadius, style: .continuous)
                .fill((dragOffset > 0 ? Palette.known : Palette.miss).opacity(swipeTint))
                .allowsHitTesting(false)
        }
        // Picked up: the shadow deepens the further the card travels.
        .shadow(color: .black.opacity(appStyle == .collage ? 0.08 * dragProgress : 0.06 + 0.06 * dragProgress),
                radius: 12 + 10 * dragProgress, y: 4 + 6 * dragProgress)
        .rotationEffect(.degrees(appStyle == .collage ? -0.8 : 0))
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
        ButtonRow {
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
        buddyMood = grade == .known ? .happy : .encourage
        let entry = model.word(id: wordId)
        let misses = model.progress(for: wordId).reviewCount + (grade == .review ? 1 : 0)
        buddyRemark = CatQuips.studied(buddyHop, known: grade == .known, word: entry.map { model.face($0).prompt },
                                       misses: misses, source: catLines)
        withAnimation(reduceMotion ? nil : Motion.reveal) {
            stuck = grade == .review && misses >= 3 ? entry.map { ($0, misses) } : nil
        }
        buddyHop += 1
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
            // When it comes back: the schedule made visible, as Anki prints it on its keys.
            if let text = comeBackText(wordId), model.studySession?.isComplete != true {
                withAnimation(reduceMotion ? nil : Motion.pop) { comeBack = (text, grade == .known) }
                comeBackTick += 1
            }
            if model.studySession?.isComplete == true { phase = .idle; cardOpacity = 1; cardScale = 1; dragOffset = 0 }
        }
    }

    /// When a card just graded comes back: later in this set, or in so many days.
    private func comeBackText(_ wordId: String) -> String? {
        if let session = model.studySession, session.cardIds.dropFirst(session.index).contains(wordId) {
            return L.t("這組等一下再翻一次", "Again later in this set")
        }
        guard let due = model.progress(for: wordId).dueDate, let dueDay = DayMath.dayNumber(due),
              let today = DayMath.dayNumber(model.today) else { return nil }
        return ClozeCard.comeBackLabel(days: max(0, dueDay - today), inThisRound: false)
    }

    /// Reads the front of each new card aloud when the learner turned that on.
    private func speakIfAutomatic(_ word: WordEntry) {
        let preferences = model.settings.speech ?? SpeechPreferences()
        guard preferences.autoSpeak == true, visible else { return }
        let face = model.face(word)
        guard Speaker.shared.activeText != face.speakText else { return }
        Speaker.shared.speak(face.speakText, language: face.speakLanguage, preferences: preferences)
    }

    /// The first card ever shows how it goes instead of saying it: it
    /// leans right until 認得 shows, then left to 不熟, and settles. With
    /// Reduce Motion or VoiceOver the cat says it in words instead.
    private func showHowToSwipe() {
        guard model.tipDue(.study), !reduceMotion, !voiceOver, !AppRuntime.uiTesting else { return }
        model.noteTipSeen(.study)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            for offset in [72.0, 0, -72, 0] as [CGFloat] {
                // A learner who has started on the card takes over.
                guard visible, phase == .idle, !revealed else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { dragOffset = offset }
                try? await Task.sleep(for: .milliseconds(offset == 0 ? 300 : 750))
            }
        }
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
                    .font(.display(.title2, weight: .bold))
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
                    if !face.examplePinyin.isEmpty {
                        Text(face.examplePinyin).font(.footnote).foregroundStyle(.secondary)
                    }
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
        .sheet(isPresented: $aiOpen) { AIWordSheet(word: word).compactSheet() }
    }
}

/// Whether the card is new, still being learned, or a scheduled review.
struct CardStatusChip: View {
    var status: WordStatus

    private var style: (text: String, color: Color) {
        switch status {
        case .new: (L.t("新字", "New"), Palette.accent)
        case .review: (L.t("還不熟", "Still learning"), Palette.review)
        case .mastered: (L.t("已會", "Known"), Palette.known)
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
    @Environment(AccountModel.self) private var account
    @State private var signInOpen = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var session: StudySession
    /// The daily goal was reached during this set.
    var reachedGoal = false
    var done: () -> Void
    var again: () -> Void
    var startQuiz: () -> Void

    /// Today's words in a quiz, while they are fresh.
    private func quizTodaysWords() {
        model.requestQuizOnTodaysWords()
        startQuiz()
    }

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
                .font(.display(.title, weight: .bold))
                .entrance(1)
            SessionVerdict(fallback: CatQuips.studyDone(reachedGoal: reachedGoal || model.goalDone, source: model.catLines),
                           mood: reachedGoal || model.goalDone ? .happy : .smug, kind: "study",
                           total: session.knownIds.count + session.reviewIds.count, correct: session.knownIds.count,
                           missedIds: session.reviewIds)
                .entrance(3)
            if account.configured, !account.isPermanent {
                GuestKeepCard(count: session.knownIds.count + session.reviewIds.count) { signInOpen = true }
                    .entrance(3)
            }
            if !session.reviewIds.isEmpty, !AppRuntime.uiTesting {
                PlusUpsellCard(feature: .smartAI,
                               title: session.reviewIds.count == 1 ? L.t("這個字，讓傻貓講給你聽", "Let Silly Cat explain this word")
                                   : L.t("這 \(session.reviewIds.count) 個字，讓傻貓講給你聽", "Let Silly Cat explain these \(session.reviewIds.count) words"),
                               detail: L.t("用法、例句、跟哪個字容易搞混，一個一個說清楚，下次就記得。", "Usage, examples and what they get mixed up with, one by one, so they stick."))
                    .entrance(4)
            }
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
            RoundEndActions(done: done, doneId: "study-done",
                            extra: reachedGoal ? quizTodaysWords : nil,
                            extraTitle: L.quizTodaysWords, extraId: "study-quiz-today",
                            again: again, againId: "study-again")
                .padding(.top, 16)
          }
          .padding(.vertical, 24)
        }
        .multilineTextAlignment(.center)
        .overlay(alignment: .top) {
            if reachedGoal && appeared && !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .sheet(isPresented: $signInOpen) { SignInSheet(reason: .general) }
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
                .font(.display(.title3, weight: .bold))
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
        // A card of its own on the paper: the ivory surface tinted by the
        // stat's colour and edged in it, so it reads at a glance.
        .background {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            shape.fill(Palette.surface)
                .overlay(shape.fill(tint.opacity(0.14)))
                .overlay(shape.strokeBorder(tint.opacity(0.28), lineWidth: 1))
        }
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

    static let paper: [Color] = [Palette.accent, Palette.known, Palette.review, Palette.chinese, Palette.miss]
    /// Gold leaf and cream, for the dark leather of a finished day.
    static let gold: [Color] = [Color(red: 0.95, green: 0.78, blue: 0.45), Color(red: 0.82, green: 0.6, blue: 0.24),
                                Color(red: 1.0, green: 0.96, blue: 0.88), Color(red: 0.98, green: 0.86, blue: 0.6)]
    @State private var start = Date()
    @State private var finished = false
    private let pieces: [Piece]

    init(colors: [Color] = ConfettiBurst.paper) {
        pieces = (0..<48).map { index in
            var random = SystemRandomNumberGenerator()
            return Piece(x: .random(in: 0...1, using: &random),
                         delay: .random(in: 0...0.5, using: &random),
                         speed: .random(in: 260...420, using: &random),
                         spin: .random(in: -4...4, using: &random),
                         drift: .random(in: -40...40, using: &random),
                         size: CGSize(width: .random(in: 6...10, using: &random), height: .random(in: 10...16, using: &random)),
                         color: colors[index % colors.count])
        }
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

/// After a guest's round: what they just did is not kept unless they sign in.
struct GuestKeepCard: View {
    var count: Int
    var signIn: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Label {
                Text(L.t("訪客模式不會保存這 \(count) 個字的進度。用 Apple 登入，現在的進度就會留下來。",
                         "As a guest, these \(count) words won't be kept. Sign in with Apple and today's progress stays."))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.icloud.fill").foregroundStyle(Palette.review)
            }
            Button(action: signIn) {
                Label(L.t("用 Apple 登入保存", "Sign in with Apple to keep it"), systemImage: "apple.logo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("summary-sign-in")
        }
        .card(radius: 18, padding: 14)
    }
}
