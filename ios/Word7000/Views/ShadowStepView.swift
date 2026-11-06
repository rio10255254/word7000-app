import SwiftUI
import AVFoundation
import Word7000Core

/// The first step of each item on the speaking path: hear a model sentence,
/// then say it back. Words (in Chinese, characters) turn green as they are
/// heard, and red when one was skipped; once all are, or when the learner
/// stops speaking, listening stops by itself and shows what came across.
/// Learning Chinese, each character's tone is drawn under it from the start,
/// and the learner's own pitch over it after a take. A sentence said well
/// moves on after a short countdown that any touch on the sentence cancels.
@MainActor
struct ShadowStepView: View {
    struct Partner {
        let role: String
        let line: String
        /// The line in the learner's own language.
        let gloss: String
    }

    /// A line said earlier in the conversation.
    struct ChatLine: Equatable, Identifiable {
        let id: String
        let text: String
        /// Said by the learner (on the right), or by the other person.
        let mine: Bool
    }

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let keyword: String
    let sentence: String
    let translation: String
    /// The sentence is Chinese (learning Chinese).
    let chinese: Bool
    /// In a role-play, who speaks first and what they say; the sentence is the reply.
    var partner: Partner? = nil
    /// In a role-play, what was said before this turn. The last line stays
    /// above, faded, so three bubbles show the conversation going on.
    var earlier: [ChatLine] = []
    /// Called with whether the sentence was said well enough (or said at
    /// all, where this phone cannot turn speech into text).
    let onDone: (_ said: Bool) -> Void

    @State private var listener = LiveListener()
    @State private var check: ShadowingCheck?
    @State private var showsTranslation = false
    /// Counting down to the next step after a sentence said well.
    @State private var advancing = false
    /// After a take with mistakes: listening starts again by itself in a
    /// moment, until the sentence is said right.
    @State private var retrying = false
    /// What to watch for on the next try: the characters (words) said wrong.
    @State private var retryFocus: [String] = []
    /// Learning Chinese: each character's measured pitch, by unit id.
    @State private var tones: [Int: ToneAnalysis.Syllable] = [:]
    /// The take before this one, kept while saying it again: its colours
    /// stay on the characters not reached yet, and its note above the key,
    /// so the learner sees what to fix while saying it.
    @State private var lastTake: ShadowingCheck?
    @State private var lastTones: [Int: ToneAnalysis.Syllable] = [:]
    /// Learning Chinese: the tone each character has as said in the phrase,
    /// by unit id, drawn under it as a guide before anything is said.
    @State private var guideTones: [Int: Int] = [:]
    /// WordCat Next: on a later turn of a role-play the other person types
    /// for a moment before their line comes in, then the reply to say.
    @State private var partnerArrived = false
    /// What the colours mean, under a take in a role-play, when asked.
    @State private var legendShown = false

    private var language: String { chinese ? "zh-TW" : "en-US" }
    private var live: Bool { listener.listening }
    /// This phone cannot turn speech into text, so saying it is enough.
    private var uncheckable: Bool { listener.support == .recordOnly }
    private var said: Bool { check?.passed ?? (uncheckable && listener.hasRecording) }
    private var tried: Bool { check != nil || listener.hasRecording }
    /// How long the result shows before moving on by itself.
    private var countdown: Duration { AppRuntime.uiTesting ? .seconds(4) : .milliseconds(1600) }

    /// While listening, what was heard turns green as it comes, and what was
    /// skipped on the way (before the last word heard) red; the rest waits.
    /// Saying it again, the characters not reached yet keep the last take's
    /// colours (a little faded) until they are said.
    private var shownUnits: [(unit: ShadowingCheck.Unit, carried: Bool)] {
        if let check, listener.isFinal { return check.units.map { ($0, false) } }
        let units = (check ?? ShadowingCheck(target: sentence, chinese: chinese)).units
        let reached = units.lastIndex { unit in
            switch unit.mark {
            case .heard, .tone: true
            default: false
            }
        }
        let before = lastTake?.units
        return units.enumerated().map { index, unit in
            var shown = unit
            if let reached, index <= reached { return (shown, false) }
            if let before, before.indices.contains(index), before[index].id == unit.id, before[index].mark != nil {
                shown.mark = before[index].mark
                return (shown, true)
            }
            shown.mark = nil
            return (shown, false)
        }
    }

    /// Long sentences in a smaller size, so they take fewer rows.
    private var textSize: ShadowUnitView.Size {
        let count = (check ?? ShadowingCheck(target: sentence, chinese: chinese)).scoredCount
        if chinese { return count <= 9 ? .large : count <= 15 ? .medium : .small }
        return count <= 8 ? .large : count <= 14 ? .medium : .small
    }

    private static let recorderID = "shadow-recorder"
    /// How long the other person "types" before their next line.
    static let typingPause: Duration = .milliseconds(850)

    var body: some View {
        VStack(spacing: 16) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        sentenceCard
                        if partner == nil {
                            recorderKey.id(Self.recorderID)
                        } else {
                            // The chat's last line: the bottom bar holds the key.
                            Color.clear.frame(height: 1).id(Self.recorderID)
                        }
                    }
                    .padding(.bottom, 12)
                }
                // A role-play opens at its newest lines, the conversation so far above.
                .defaultScrollAnchor(partner == nil ? .top : .bottom)
                // A later turn of a role-play scrolls like a chat: on a small phone
                // the oldest line moves up out of the way, so the new lines and the
                // key stay in full view.
                .task(id: sentence) {
                    guard !earlier.isEmpty else { return }
                    // Once the other person's line and the reply have come in.
                    do { try await Task.sleep(for: reduceMotion ? .milliseconds(50) : Self.typingPause + .milliseconds(420)) } catch { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                        proxy.scrollTo(Self.recorderID, anchor: .bottom)
                    }
                }
                // While speaking, and when the result shows, the key and the
                // line under it stay in full view above the buttons.
                .onChange(of: live) { _, now in
                    guard now else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        proxy.scrollTo(Self.recorderID, anchor: .bottom)
                    }
                }
                .onChange(of: listener.isFinal) { _, final in
                    guard final else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        proxy.scrollTo(Self.recorderID, anchor: .bottom)
                    }
                }
            }
            if partner != nil {
                chatBar
                    .opacity(arrived ? 1 : 0.35)
                    .allowsHitTesting(arrived)
            } else {
                ButtonRow {
                    skipKey
                    nextKey
                }
            }
        }
        .task { await listener.refresh(language: language) }
        .task(id: sentence) {
            guard !arrived else { return }
            do { try await Task.sleep(for: Self.typingPause) } catch { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { partnerArrived = true }
        }
        .sensoryFeedback(trigger: partnerArrived) { _, now in
            now && (model.settings.hapticsEnabled ?? true) ? .impact(weight: .light) : nil
        }
        .task(id: sentence) {
            guideTones = chinese ? Self.tonesAsSaid(in: sentence) : [:]
            lastTake = nil; lastTones = [:]; retryFocus = []
        }
        .onAppear {
            #if DEBUG
            // A simulated take says the sentence back.
            listener.simulatedText = sentence
            #endif
        }
        .onDisappear { listener.clear() }
        .onChange(of: listener.text) { _, heard in
            guard !heard.isEmpty else { return }
            let next = ShadowingCheck(target: sentence, heard: heard, chinese: chinese)
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { check = next }
        }
        .onChange(of: listener.isFinal) { _, final in
            guard final else { return }
            // Nothing heard this time: the last take's colours stay to go by.
            if !listener.text.isEmpty { lastTake = nil; lastTones = [:] }
            if !listener.text.isEmpty {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.3)) {
                    check = ShadowingCheck(target: sentence, heard: listener.text, chinese: chinese)
                }
            } else if listener.support != .recordOnly {
                withAnimation { check = ShadowingCheck(target: sentence, heard: "", chinese: chinese) }
            }
            Task {
                if chinese { await measureTones() }
                guard let check, listener.isFinal else { return }
                // Only a sentence said right all through moves on by itself.
                if check.perfect { advancing = true; return }
                // Otherwise, once there is something to fix, the key listens
                // again by itself, until it is said right (Skip and Next still work).
                guard listener.heardVoice, !listener.text.isEmpty else { return }
                retryFocus = check.units.filter { $0.scored && $0.mark != .heard }.map(\.text)
                retrying = true
            }
        }
        // Stops by itself: everything heard, or the learner stopped speaking
        // (by the voice's loudness, so also where no text comes while speaking).
        .task(id: live) {
            guard live else { return }
            while !Task.isCancelled, listener.listening {
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                guard listener.listening else { return }
                let complete = check.map { $0.heardCount == $0.scoredCount && $0.scoredCount > 0 } ?? false
                if complete, listener.quietFor > 0.35 { listener.stop(); return }
                // The last character was reached, though some were missed on the way.
                let lastScored = check?.units.last(where: \.scored)
                let reachedEnd = lastScored.map { $0.mark != nil && $0.mark != .missed } ?? false
                if reachedEnd, listener.quietFor > 0.6 { listener.stop(); return }
                if listener.heardVoice, listener.silentFor > 1.0 { listener.stop(); return }
                if listener.support == .live, !listener.text.isEmpty, listener.quietFor > 2.5 { listener.stop(); return }
                if !listener.heardVoice, listener.text.isEmpty, listener.seconds > 8 { listener.stop(); return }
                if listener.seconds > 30 { listener.stop(); return }
            }
        }
        .task(id: retrying) {
            guard retrying else { return }
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 1400 : 1800)) } catch { return }
            guard retrying, !listener.busy, scenePhase == .active else { retrying = false; return }
            retrying = false
            sayAgain()
        }
        .task(id: advancing) {
            guard advancing else { return }
            do { try await Task.sleep(for: countdown) } catch { return }
            guard advancing else { return }
            finish()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { hold(); listener.interrupt(); Speaker.shared.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in listener.interrupt() }
        // A light tick for each newly heard word, a success at the end.
        .sensoryFeedback(trigger: check?.heardCount ?? 0) { old, new in
            guard model.settings.hapticsEnabled ?? true, live, new > old else { return nil }
            return .selection
        }
        .sensoryFeedback(trigger: listener.isFinal ? check?.passed : nil) { _, passed in
            guard model.settings.hapticsEnabled ?? true, let passed else { return nil }
            return passed ? .success : .warning
        }
        .sensoryFeedback(trigger: live) { _, new in
            guard model.settings.hapticsEnabled ?? true else { return nil }
            return .impact(weight: new ? .medium : .light)
        }
    }

    private var skipKey: some View {
        Button { finish() } label: {
            Text(L.t("跳過", "Skip")).font(.headline).frame(maxWidth: .infinity)
        }
        .secondaryAction()
        .accessibilityIdentifier("shadow-skip")
    }

    private var nextKey: some View {
        Button { finish() } label: {
            Text(L.t("下一步：回答問題", "Next: answer")).font(.headline).frame(maxWidth: .infinity)
        }
        .prominentAction(tint: said ? Palette.known : Palette.accent)
        .overlay(alignment: .leading) { countdownFill }
        .disabled(!tried || listener.busy)
        .accessibilityIdentifier("shadow-next")
    }

    /// WordCat Next: a role-play's bottom bar, where a chat's input bar is:
    /// what to do in one line, the record key in the middle (hearing one's
    /// own take beside it), Skip on the left and Next on the right.
    private var chatBar: some View {
        VStack(spacing: 10) {
            keyHint
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(live ? Palette.miss : Palette.secondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.opacity)
            HStack(alignment: .center, spacing: 12) {
                Button { finish() } label: {
                    Text(L.t("跳過", "Skip")).font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondaryLabel)
                .accessibilityIdentifier("shadow-skip")
                // The same big key as everywhere else: it is where the eye goes.
                ZStack {
                    if live && !reduceMotion {
                        Circle()
                            .stroke(Palette.miss.opacity(0.3), lineWidth: 3)
                            .frame(width: 112, height: 112)
                            .scaleEffect(1.15 + CGFloat(listener.level) * 0.35)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: listener.level)
                    }
                    micButton(size: 112, symbol: 40)
                }
                .frame(width: 136, height: 136)
                // Hearing one's own take: a small key on the big one's corner.
                .overlay(alignment: .bottomLeading) {
                    if listener.hasRecording && !live {
                        playKey.scaleEffect(0.8).offset(x: -4, y: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Button { finish() } label: {
                    HStack(spacing: 4) {
                        Text(L.t("下一步", "Next"))
                        Image(systemName: "arrow.down")
                    }
                    .font(.headline)
                    .foregroundStyle(tried ? .white : Palette.tertiaryLabel)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(tried ? (said ? Palette.known : Palette.accent) : Palette.fill, in: Capsule())
                    .overlay(alignment: .leading) { countdownFill.clipShape(Capsule()) }
                }
                .buttonStyle(SoftPressStyle())
                .disabled(!tried || listener.busy)
                .animation(reduceMotion ? nil : Motion.reveal, value: tried)
                .accessibilityIdentifier("shadow-next")
            }
            if let message = listener.message {
                Text(message).font(.footnote).foregroundStyle(Palette.miss)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
    }

    /// The Next key filling up while it counts down.
    @ViewBuilder
    private var countdownFill: some View {
        if advancing {
            GeometryReader { proxy in
                Rectangle()
                    .fill(.white.opacity(0.22))
                    .frame(width: proxy.size.width)
                    .modifier(CountdownWipe(duration: countdown, reduceMotion: reduceMotion))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: The sentence

    /// The other person's line, on the left like a chat message, with who
    /// says it in small type. Tapping it shows the translation.
    private func partnerBubble(_ partner: Partner) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(partner.role).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(partner.line).font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("shadow-partner-line")
                if chinese {
                    let pinyin = ChineseDisplay.readablePinyin(ChineseDisplay.sentencePinyin(partner.line))
                    if !pinyin.isEmpty { Text(pinyin).font(.footnote).foregroundStyle(.secondary) }
                }
                if showsTranslation, !partner.gloss.isEmpty {
                    Text(partner.gloss).font(.subheadline).foregroundStyle(Palette.accent)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.fill, in: BubbleShape(tail: .leading))
            .contentShape(Rectangle())
            .onTapGesture { toggleTranslation() }
            // Hear it, and see the whole exchange translated.
            VStack(spacing: 12) {
                SpeakButton(text: partner.line, language: language)
                    .simultaneousGesture(TapGesture().onEnded { hold() })
                translateKey
            }
            Spacer(minLength: 24)
        }
    }

    /// The sentence to say, large: on the right like one's own message in a
    /// role-play, plain otherwise. Tapping it shows the translation.
    @ViewBuilder
    private var replyBlock: some View {
        if partner != nil {
            HStack(alignment: .center, spacing: 6) {
                // Room for the sentence first, so a short one stays on one row.
                Spacer(minLength: 0)
                SpeakButton(text: sentence, language: language)
                    .simultaneousGesture(TapGesture().onEnded { hold() })
                    .accessibilityIdentifier("shadow-listen")
                replyText
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Palette.accent.opacity(0.12), in: BubbleShape(tail: .trailing))
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                replyText
                Spacer(minLength: 0)
                replyKeys
            }
        }
    }

    private var replyText: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: chinese ? 1 : 7, lineSpacing: chinese ? 8 : 6, balanced: true) {
                let size = textSize
                ForEach(shownUnits, id: \.unit.id) { shown in
                    ShadowUnitView(unit: shown.unit, chinese: chinese, showsPinyin: chinese, size: size,
                                   tone: shown.carried ? lastTones[shown.unit.id] : tones[shown.unit.id],
                                   guide: guideTones[shown.unit.id])
                        .opacity(shown.carried ? 0.6 : 1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sentence)
            .accessibilityIdentifier("shadow-sentence")
            if showsTranslation, !translation.isEmpty {
                Text(translation).font(.subheadline).foregroundStyle(Palette.accent)
                    .accessibilityIdentifier("shadow-translation-text")
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleTranslation() }
    }

    /// Hear the sentence, and see it translated.
    private var replyKeys: some View {
        VStack(spacing: 12) {
            SpeakButton(text: sentence, language: language)
                .simultaneousGesture(TapGesture().onEnded { hold() })
                .accessibilityIdentifier("shadow-listen")
            translateKey
        }
    }

    @ViewBuilder
    private var translateKey: some View {
        if !translation.isEmpty || !(partner?.gloss ?? "").isEmpty {
            Button { toggleTranslation() } label: {
                Image(systemName: showsTranslation ? "character.bubble.fill" : "character.bubble")
                    .font(.title3)
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(showsTranslation ? L.t("收起翻譯", "Hide translation") : L.t("看翻譯", "Show translation"))
            .accessibilityIdentifier("shadow-translation")
        }
    }

    /// Another take: the last one's colours and notes stay until this one is
    /// checked, so the learner knows what to fix while saying it.
    private func sayAgain() {
        Speaker.shared.stop()
        if let check, listener.isFinal, !listener.text.isEmpty {
            lastTake = check.perfect ? nil : check
            lastTones = check.perfect ? [:] : tones
            retryFocus = check.units.filter { $0.scored && $0.mark != .heard }.map(\.text)
        }
        check = nil; tones = [:]
        listener.start()
    }

    /// Any touch on the sentence or its keys: stay on this step for now.
    private func hold() {
        advancing = false
        retrying = false
    }

    private func toggleTranslation() {
        hold()
        guard !translation.isEmpty || !(partner?.gloss ?? "").isEmpty else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { showsTranslation.toggle() }
    }

    private var sentenceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if partner != nil, !earlier.isEmpty {
                ChatHistory(lines: earlier)
            }
            if let partner {
                if arrived {
                    partnerBubble(partner).modifier(ChatRise(step: 0))
                    // Only a role-play rolls on like a chat.
                    replyBlock.modifier(ChatRise(step: 2))
                } else {
                    ChatTypingBubble()
                        .transition(.opacity)
                        .accessibilityIdentifier("speaking-typing")
                }
            } else {
                replyBlock
            }
            if let check, listener.isFinal { result(check, tones: tones) }
            else if let lastTake { result(lastTake, tones: lastTones).opacity(0.6) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A role-play is a chat on the page itself; a word's sentence sits on a card.
        .modifier(OptionalCard(enabled: partner == nil))
    }

    /// The first turn, a word, or reduced motion: no typing pause.
    private var arrived: Bool { partnerArrived || earlier.isEmpty || reduceMotion }

    @ViewBuilder
    private func result(_ check: ShadowingCheck, tones: [Int: ToneAnalysis.Syllable]) -> some View {
        if partner != nil {
            chatResult(check, tones: tones)
        } else {
            cardResult(check, tones: tones)
        }
    }

    /// Under the learner's bubble, on its side: the score as a small badge,
    /// what to fix in a line, and what the colours mean only when asked.
    private func chatResult(_ check: ShadowingCheck, tones: [Int: ToneAnalysis.Syllable]) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text(resultLine(check))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(check.perfect ? Palette.known : Palette.review)
                    .multilineTextAlignment(.trailing)
                Text("\(Int((check.score * 100).rounded()))%")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(check.perfect ? Palette.known : Palette.review, in: Capsule())
                    .symbolEffect(.bounce, value: reduceMotion ? false : check.passed)
                if check.heardCount < check.scoredCount {
                    Button { withAnimation(reduceMotion ? nil : Motion.reveal) { legendShown.toggle() } } label: {
                        Image(systemName: "questionmark.circle").font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.secondaryLabel)
                    .accessibilityLabel(L.t("顏色的意思", "What the colours mean"))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("shadow-result")
            if let note = toneNote(check, tones: tones) {
                Text(note).font(.footnote).foregroundStyle(Palette.review)
            }
            if legendShown, check.heardCount < check.scoredCount {
                HStack(spacing: 10) {
                    legend(Palette.known, L.t("聽到了", "Heard"))
                    if check.toneCount > 0 { legend(Palette.review, L.t("聲調不同", "Other tone")) }
                    if check.units.contains(where: { $0.mark == .missed }) { legend(Palette.miss, L.t("沒聽到", "Not heard")) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }
            if PushRegistration.shared.isTester {
                Text("\(diagnostics)・音高 \(tones.count)/\(check.scoredCount) 字")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier("shadow-diagnostics")
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
    }

    private func resultLine(_ check: ShadowingCheck) -> String {
        check.perfect ? L.t("全部念對了！", "All of it, right!")
            : listener.text.isEmpty && listener.support == .live ? L.t("沒聽清楚，靠近一點再說一次", "Didn't catch that. Closer, once more")
            : check.passed ? L.t("差一點，黃色紅色的再念一次", "Almost. The yellow and red again")
            : L.t("再念一次看看", "Once more")
    }

    private func cardResult(_ check: ShadowingCheck, tones: [Int: ToneAnalysis.Syllable]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: check.perfect ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(check.perfect ? Palette.known : Palette.review)
                    .font(.title3)
                    .symbolEffect(.bounce, value: reduceMotion ? false : check.passed)
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.perfect ? L.t("全部念對了！", "All of it, right!")
                         : listener.text.isEmpty && listener.support == .live ? L.t("沒聽清楚，靠近一點再說一次？", "Didn't catch that. Closer, and once more?")
                         : check.passed ? L.t("差一點，把黃色、紅色的字再念一次", "Almost. Say the yellow and red ones again")
                         : L.t("再念一次看看", "Once more"))
                        .font(.headline)
                    if let note = toneNote(check, tones: tones) {
                        Text(note).font(.subheadline).foregroundStyle(Palette.review)
                    }
                }
                Spacer()
                Text("\(Int((check.score * 100).rounded()))%")
                    .font(.display(.title3, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(check.perfect ? Palette.known : Palette.review)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("shadow-result")
            // What the colours mean, only when something was not heard as written.
            if check.heardCount < check.scoredCount {
                HStack(spacing: 12) {
                    legend(Palette.known, L.t("聽到了", "Heard"))
                    if check.toneCount > 0 { legend(Palette.review, L.t("聲調不同", "Other tone")) }
                    if check.units.contains(where: { $0.mark == .missed }) { legend(Palette.miss, L.t("沒聽到", "Not heard")) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            // Test phones only: which recognizer listened, and whether text
            // came while speaking (live colouring needs it).
            if PushRegistration.shared.isTester {
                Text("\(diagnostics)・音高 \(tones.count)/\(check.scoredCount) 字")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier("shadow-diagnostics")
            }
        }
        .padding(.top, 4)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
    }

    /// Test phones: which recognizers listened and how often each answered
    /// while speaking (live colouring needs those answers).
    private var diagnostics: String {
        let used = ["new": "新版", "old": "舊版", "both": "新版＋舊版"][listener.recognizerUsed] ?? "無"
        return "辨識：\(used)・\(listener.takePath)・即時 \(listener.liveUpdates) 次（新 \(listener.newUpdates)／舊 \(listener.oldUpdates)）"
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    // MARK: Recording

    /// The big key, with hearing one's own take as a small key beside it.
    private var recorderKey: some View {
        VStack(spacing: 8) {
            HStack(spacing: 28) {
                playKey.opacity(listener.hasRecording && !live ? 1 : 0)
                ZStack {
                    if live && !reduceMotion {
                        Circle()
                            .stroke(Palette.miss.opacity(0.3), lineWidth: 3)
                            .frame(width: 112, height: 112)
                            .scaleEffect(1.15 + CGFloat(listener.level) * 0.35)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: listener.level)
                    }
                    micButton(size: 112, symbol: 40)
                }
                .frame(height: 136)
                // Balances the play key so the big key stays centred.
                Color.clear.frame(width: 48, height: 48)
            }
            keyHint
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .contentTransition(.opacity)
            if live, PushRegistration.shared.isTester {
                Text(diagnostics)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            if let message = listener.message {
                Text(message).font(.footnote).foregroundStyle(Palette.miss)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if uncheckable, listener.hasRecording {
                Text(L.t("這支手機無法自動比對，聽聽自己的錄音，和示範比較看看。", "This iPhone can't check it. Play your take back and compare it with the model."))
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func micButton(size: CGFloat, symbol: CGFloat) -> some View {
        Button {
            hold()
            if live { listener.stop() } else { sayAgain() }
        } label: {
            Image(systemName: live ? "stop.fill" : (tried ? "arrow.counterclockwise" : "mic.fill"))
                .font(.system(size: symbol, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(MicKeyStyle(live: live, size: size))
        .disabled(listener.state == .requesting || listener.state == .finishing)
        .accessibilityLabel(live ? L.t("停止", "Stop") : tried ? L.t("再說一次", "Say it again") : L.t("開始說", "Start speaking"))
        .accessibilityIdentifier("shadow-record")
    }

    /// What the key does now, in one line.
    private var keyHint: some View {
        Group {
                if live {
                    Text(!retryFocus.isEmpty
                         ? L.t("注意「\(retryFocus.prefix(3).joined(separator: "、"))」，說完會自動停", "Mind \(retryFocus.prefix(3).joined(separator: ", ")); it stops when you're done")
                         : listener.text.isEmpty && !listener.heardVoice ? L.t("請說…", "Go ahead…")
                         : L.t("繼續說，說完會自動停", "Keep going; it stops when you're done"))
                } else if listener.state == .finishing {
                    HStack(spacing: 6) { ProgressView(); Text(L.t("聽聽看你說了什麼…", "Listening back…")) }
                } else if advancing {
                    Text(L.t("馬上進入下一步", "On to the next step"))
                } else if retrying {
                    Text(L.t("馬上再聽你念一次…", "Listening again in a moment…"))
                } else if tried {
                    Text(L.t("按一下再說一次", "Tap to say it again"))
                } else if earlier.isEmpty {
                    // Once a line of the role-play has been said, the key explains itself.
                    Text(L.t("聽完後，按一下跟著說", "Listen, then tap and say it"))
                } else {
                    // Keeps the line's room, so the page does not jump when it fills.
                    Text(" ").accessibilityHidden(true)
                }
        }
    }

    private var playKey: some View {
        Button {
            hold()
            listener.togglePlayback()
        } label: {
            Image(systemName: listener.state == .playing ? "stop.fill" : "play.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 48, height: 48)
                .background(Palette.accent.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!listener.hasRecording || live)
        .accessibilityLabel(listener.state == .playing ? L.t("停止播放", "Stop playback") : L.t("聽自己的錄音", "Hear yourself"))
        .accessibilityIdentifier("shadow-play")
    }

    /// Learning Chinese: the pitch of each character said, against the tone
    /// it should have. Recognition writes a character right even when its
    /// tone was off; the pitch tells.
    private func measureTones() async {
        guard let current = check else { return }
        let scored = current.units.filter(\.scored)
        #if DEBUG
        // App Store screens: the pitch lines as a real take draws them, with
        // one tone slip, since the simulator has no voice to measure.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingToneShowcase") {
            showcaseTones(current, scored: scored)
            return
        }
        #endif
        let (samples, rate) = listener.samples
        guard !scored.isEmpty, !samples.isEmpty else { return }
        let characters = scored.map(\.text)
        let expected = ToneAnalysis.spokenTones(characters: characters, syllables: scored.map(\.pinyin))
        let pieces = listener.segments.map { (text: $0.text, start: $0.start, duration: $0.duration) }
        let measured = await Task.detached(priority: .userInitiated) { () -> [ToneAnalysis.Syllable?] in
            var spans = ToneAnalysis.spans(of: characters, in: pieces)
            if spans.allSatisfy({ $0 == nil }) {
                spans = ToneAnalysis.evenSpans(samples: samples, rate: rate, count: characters.count)
            }
            return ToneAnalysis.analyze(samples: samples, rate: rate, spans: spans, expected: expected)
        }.value
        guard check == current else { return }
        var found: [Int: ToneAnalysis.Syllable] = [:]
        var slips: [Int: String] = [:]
        for (unit, syllable) in zip(scored, measured) {
            guard let syllable else { continue }
            found[unit.id] = syllable
            if syllable.mismatched, let heard = syllable.heard, unit.mark == .heard {
                slips[unit.id] = ToneAnalysis.syllable(unit.pinyin, withTone: heard)
            }
        }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
            tones = found
            check = current.withToneSlips(slips)
        }
    }

    #if DEBUG
    private func showcaseTones(_ current: ShadowingCheck, scored: [ShadowingCheck.Unit]) {
        let expected = ToneAnalysis.spokenTones(characters: scored.map(\.text), syllables: scored.map(\.pinyin))
        func contour(_ tone: Int) -> [Double] {
            switch tone {
            case 1: [4.5, 4.6, 4.6, 4.5]
            case 2: [2.8, 3.1, 3.8, 4.5]
            case 3: [2.4, 1.6, 1.3, 2.1]
            case 4: [4.7, 4.0, 3.0, 1.9]
            default: [3.0, 2.8, 2.7]
            }
        }
        // The second syllable that has a tone of its own comes out flat.
        let slipAt = expected.indices.filter { expected[$0] != 5 && expected[$0] != 1 }.dropFirst().first
        var found: [Int: ToneAnalysis.Syllable] = [:]
        var slips: [Int: String] = [:]
        for (index, unit) in scored.enumerated() {
            let tone = expected[index]
            let heard = index == slipAt ? 1 : tone
            found[unit.id] = ToneAnalysis.Syllable(expected: tone, heard: heard, contour: contour(heard))
            if heard != tone { slips[unit.id] = ToneAnalysis.syllable(unit.pinyin, withTone: heard) }
        }
        tones = found
        check = current.withToneSlips(slips)
    }
    #endif

    /// Each character's tone as said in the phrase (with the changes for 一,
    /// 不 and two third tones), by unit id.
    private static func tonesAsSaid(in sentence: String) -> [Int: Int] {
        let scored = ShadowingCheck(target: sentence, chinese: true).units.filter(\.scored)
        let tones = ToneAnalysis.spokenTones(characters: scored.map(\.text), syllables: scored.map(\.pinyin))
        guard tones.count == scored.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(scored.map(\.id), tones))
    }

    /// "馬 sounded like a first tone", for the first tone slip.
    private func toneNote(_ check: ShadowingCheck, tones: [Int: ToneAnalysis.Syllable]) -> String? {
        guard let unit = check.units.first(where: { if case .tone = $0.mark { true } else { false } }),
              let heard = tones[unit.id]?.heard else { return nil }
        return L.t("「\(unit.text)」聽起來像\(ToneAnalysis.toneName(heard))", "\u{201C}\(unit.text)\u{201D} sounded like tone \(heard)")
    }

    private func finish() {
        hold()
        listener.interrupt()
        Speaker.shared.stop()
        onDone(said)
    }
}

/// The last line said before this turn, small and faded above it, so the
/// conversation reads on from where it was.
struct EarlierChatLine: View {
    let line: ShadowStepView.ChatLine

    var body: some View {
        HStack {
            if line.mine { Spacer(minLength: 56) }
            Text(line.text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.head)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((line.mine ? Palette.accent.opacity(0.07) : Palette.fill.opacity(0.55)),
                            in: BubbleShape(tail: line.mine ? .trailing : .leading))
            if !line.mine { Spacer(minLength: 56) }
        }
        .opacity(0.8)
        .accessibilityLabel(L.t("上一句：\(line.text)", "Before: \(line.text)"))
        .accessibilityIdentifier("speaking-earlier-line")
    }
}

/// The other person typing: three dots in their bubble.
struct ChatTypingBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { dot in
                    Circle()
                        .fill(Palette.secondaryLabel)
                        .frame(width: 8, height: 8)
                        .phaseAnimator(reduceMotion ? [1.0] : [0.3, 1.0]) { content, phase in content.opacity(phase) } animation: { _ in
                            .easeInOut(duration: 0.4).delay(Double(dot) * 0.14)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.fill, in: BubbleShape(tail: .leading))
            Spacer(minLength: 0)
        }
        .accessibilityLabel(L.t("對方正在輸入", "Typing"))
    }
}

/// WordCat Next: everything said so far in a role-play, as a chat: the
/// other person's lines on the left, the learner's on the right (what they
/// actually answered when they did, else the reply they repeated). The
/// oldest lines are a little fainter. Shown above each step of each turn,
/// so moving on reads as the conversation scrolling on, not a new page.
struct ChatHistory: View {
    let lines: [ShadowStepView.ChatLine]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                let age = lines.count - 1 - index
                HStack(alignment: .bottom, spacing: 0) {
                    if line.mine { Spacer(minLength: 56) }
                    Text(line.text)
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(line.mine ? Palette.accent.opacity(0.14) : Palette.fill,
                                    in: BubbleShape(tail: line.mine ? .trailing : .leading))
                    if !line.mine { Spacer(minLength: 56) }
                }
                .opacity(age > 3 ? 0.55 : age > 1 ? 0.75 : 0.9)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(line.mine ? L.t("我：\(line.text)", "Me: \(line.text)") : line.text)
                .accessibilityIdentifier(index == lines.count - 1 ? "speaking-earlier-line" : "speaking-history-line")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A turn of the conversation arriving like a chat scrolling on: the line
/// from before rises into place above, then the new bubbles come up from
/// below, one after the other.
struct ChatRise: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 first; each step a little later.
    var step: Int
    /// How far below it starts.
    var from: CGFloat = 36
    var enabled = true
    @State private var risen = false

    func body(content: Content) -> some View {
        let settled = risen || reduceMotion || !enabled
        return content
            .offset(y: settled ? 0 : from)
            .opacity(settled || step == 0 ? 1 : 0)
            .onAppear {
                guard !risen, !reduceMotion else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86).delay(0.05 + Double(step) * 0.14)) { risen = true }
            }
    }
}

/// Fills a bar from left to right over `duration`.
private struct CountdownWipe: ViewModifier {
    let duration: Duration
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: reduceMotion ? 1 : progress, y: 1, anchor: .leading)
            .opacity(reduceMotion ? 0 : 1)
            .onAppear {
                let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
                withAnimation(.linear(duration: seconds)) { progress = 1 }
            }
    }
}

/// One word, or one Chinese character with its pinyin, coloured by how it came across.
struct ShadowUnitView: View {
    /// Long sentences are set smaller, so they take fewer rows.
    enum Size { case large, medium, small }

    let unit: ShadowingCheck.Unit
    let chinese: Bool
    let showsPinyin: Bool
    var size: Size = .large
    /// The pitch measured for this character, drawn under it.
    var tone: ToneAnalysis.Syllable? = nil
    /// The tone it should have, drawn under it until a take is measured.
    var guide: Int? = nil

    private var color: Color {
        switch unit.mark {
        case .none: Palette.ink
        case .heard: Palette.known
        case .tone: Palette.review
        case .missed: Palette.miss
        }
    }

    private var characterFont: Font {
        switch size {
        case .large: .title.weight(.semibold)
        case .medium: .title2.weight(.semibold)
        case .small: .title3.weight(.semibold)
        }
    }

    private var wordFont: Font {
        switch size {
        case .large: .title2.weight(.semibold)
        case .medium: .title3.weight(.semibold)
        case .small: .headline
        }
    }

    /// A character's column: wide enough for its pinyin, no wider.
    private var columnWidth: CGFloat {
        switch size {
        case .large: 30
        case .medium: 26
        case .small: 22
        }
    }

    var body: some View {
        if chinese {
            VStack(spacing: 1) {
                Text(pinyin)
                    .font(.caption.weight(unit.mark == nil ? .regular : .semibold))
                    .foregroundStyle(unit.mark == nil ? Palette.secondaryLabel : color)
                    .lineLimit(1)
                    .fixedSize()
                Text(unit.text)
                    .font(characterFont)
                    .foregroundStyle(unit.scored ? color : Palette.secondaryLabel)
                if unit.scored {
                    ToneCurve(syllable: tone, expected: guide, color: color, judged: unit.mark != nil, heardTone: heardTone)
                        .frame(width: columnWidth - 6, height: 12)
                        .opacity(tone == nil && guide == nil ? 0 : 1)
                } else {
                    // Punctuation keeps the same rows as a character, so it sits
                    // on the line instead of dropping below it.
                    Color.clear.frame(width: 1, height: 12)
                }
            }
            .frame(minWidth: unit.scored ? columnWidth : 0)
            // Full-width punctuation sits close to the character before it.
            .padding(.horizontal, unit.scored ? 0 : -6)
            .animation(.easeOut(duration: 0.2), value: unit.mark)
        } else {
            Text(unit.text)
                .font(wordFont)
                .foregroundStyle(color)
                .underline(unit.mark == .missed, color: Palette.miss)
                .animation(.easeOut(duration: 0.2), value: unit.mark)
        }
    }

    /// The tone heard instead, when only the tone differed.
    private var heardTone: Int? {
        if case .tone(let heard) = unit.mark { return ToneAnalysis.tone(of: heard) }
        return nil
    }

    /// The expected reading, or the one heard instead when only the tone differed.
    private var pinyin: String {
        guard showsPinyin, unit.scored else { return " " }
        if case .tone(let heard) = unit.mark { return heard }
        return unit.pinyin
    }
}

/// Lays children out in rows, wrapping to the next row when one is full.
/// Balanced, the rows come out about the same length (as CSS `text-wrap: balance`),
/// so a sentence never ends with one word or character alone on its last row.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    var balanced = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + row.height - size.height), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        let rows = greedyRows(width: width, subviews: subviews)
        guard balanced, rows.count > 1, width.isFinite else { return rows }
        // The narrowest width that still needs no more rows.
        var low = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        var high = width
        guard low < high else { return rows }
        while high - low > 1 {
            let middle = (low + high) / 2
            if greedyRows(width: middle, subviews: subviews).count > rows.count { low = middle } else { high = middle }
        }
        return greedyRows(width: high, subviews: subviews)
    }

    private func greedyRows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

/// A chat bubble with a small tail at the bottom, on the speaker's side.
struct BubbleShape: Shape {
    enum Tail { case leading, trailing }
    var tail: Tail

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        var path = Path(roundedRect: rect, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        let x = tail == .leading ? rect.minX + 6 : rect.maxX - 6
        let out: CGFloat = tail == .leading ? -6 : 6
        path.move(to: CGPoint(x: x, y: rect.maxY - 14))
        path.addQuadCurve(to: CGPoint(x: x + out, y: rect.maxY + 2), control: CGPoint(x: x, y: rect.maxY - 2))
        path.addQuadCurve(to: CGPoint(x: x - out * 2, y: rect.maxY - 4), control: CGPoint(x: x - out * 0.5, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// One character's pitch: before a take, the tone's shape as a guide; after
/// one, that shape as a faint dashed line and the learner's own as a solid
/// one, on the same low-to-high scale. The neutral tone is a short dot.
struct ToneCurve: View {
    let syllable: ToneAnalysis.Syllable?
    /// The tone the character should have.
    var expected: Int? = nil
    let color: Color
    /// A take has marked this character: the shape takes its colour (green
    /// when right), even where no pitch could be measured.
    var judged = false
    /// The tone recognition heard instead, drawn over the expected one.
    var heardTone: Int? = nil

    var body: some View {
        Canvas { context, size in
            func path(_ values: [Double]) -> Path {
                var path = Path()
                for (index, value) in values.enumerated() {
                    let x = size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = size.height * (1 - CGFloat((value - 1) / 4))
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                return path
            }
            if let syllable {
                context.stroke(path(ToneAnalysis.shape(of: syllable.expected)), with: .color(Palette.secondaryLabel.opacity(0.6)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 2]))
                context.stroke(path(syllable.contour), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else if let expected {
                let guide = judged ? color : Palette.secondaryLabel.opacity(0.75)
                if let heardTone, heardTone != expected {
                    context.stroke(path(ToneAnalysis.shape(of: expected)), with: .color(Palette.secondaryLabel.opacity(0.6)),
                                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 2]))
                    context.stroke(path(ToneAnalysis.shape(of: heardTone)), with: .color(color),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                } else if expected == 5 {
                    let dot = CGRect(x: size.width / 2 - 2, y: size.height / 2 - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: dot), with: .color(guide))
                } else {
                    context.stroke(path(ToneAnalysis.shape(of: expected)), with: .color(guide),
                                   style: StrokeStyle(lineWidth: judged ? 2 : 1.6, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A card around the content, or nothing.
struct OptionalCard: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.card(radius: Metrics.wordCardRadius, padding: 18)
        } else {
            content.padding(.horizontal, 2).padding(.top, 4)
        }
    }
}
