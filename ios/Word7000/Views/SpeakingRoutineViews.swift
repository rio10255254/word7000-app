import SwiftUI
import AVFoundation
import Word7000Core

// WordCat Next: a speaking stage as four steps. First listen to the whole
// conversation; then, turn by turn, say the model reply after hearing it and
// answer in one's own words (SpeakingSessionView, as before); last, use one
// of today's words in a sentence of one's own. Big type, and the cat says
// what to do.

/// Where a speaking stage is.
enum SpeakingStep: Int, Comparable {
    case listen, shadow, answer, useWord, done

    static func < (a: SpeakingStep, b: SpeakingStep) -> Bool { a.rawValue < b.rawValue }
}

/// WordCat Next: where a scenario stage is, the way today's words show
/// theirs: "第 2 步，共 3 步 · 跟讀" over three equal parts (listen, the
/// conversation turn by turn, one of today's words). The turn count stays
/// at the top of the screen.
struct SpeakingStepStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var step: SpeakingStep
    /// The turn under way (0-based) and how many there are.
    var turn: Int
    var turns: Int

    private var current: Int {
        switch step {
        case .listen: 0
        case .shadow, .answer: 1
        case .useWord, .done: 2
        }
    }

    private var fills: [Double] {
        let talk = Double(turn) / Double(max(1, turns))
        switch step {
        case .listen: return [0.15, 0, 0]
        case .shadow, .answer: return [1, max(0.06, talk), 0]
        case .useWord: return [1, 1, 0.15]
        case .done: return [1, 1, 1]
        }
    }

    private var label: String {
        switch step {
        case .listen: L.t("先聽一遍", "Listen first")
        case .shadow: L.t("跟讀", "Repeat")
        case .answer: L.t("回答", "Answer")
        case .useWord, .done: L.t("用今天的字", "Use today's word")
        }
    }

    var body: some View {
        let parts = fills
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L.t("第 \(current + 1) 步，共 3 步", "Step \(current + 1) of 3"))
                    .foregroundStyle(Palette.secondaryLabel)
                Text("·").foregroundStyle(Palette.tertiaryLabel)
                Text(label).foregroundStyle(Palette.known)
            }
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, fill in
                    GeometryReader { proxy in
                        Capsule().fill(Palette.fill)
                            .overlay(alignment: .leading) {
                                Capsule().fill(index < current ? Palette.known : Palette.accent)
                                    .frame(width: max(fill > 0 ? 8 : 0, proxy.size.width * fill))
                                    .animation(reduceMotion ? nil : Motion.fill, value: fill)
                            }
                    }
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("第 \(current + 1) 步，共 3 步，", "Step \(current + 1) of 3, ") + label)
        .accessibilityIdentifier("speaking-steps")
    }
}

/// The first step: the whole conversation of the stage as a chat room.
/// The other person writes from the left with their face and name, the
/// learner's lines arrive on the right; each line appears as it is read
/// aloud, after a moment of "typing", and the play key sits where a chat's
/// input bar would.
struct SpeakingListenView: View {
    struct Line: Identifiable, Equatable {
        let id: Int
        let text: String
        let gloss: String
        /// Said by the learner's side (on the right).
        let mine: Bool
        /// Who says it: the role (a waiter, the doctor), or "me".
        var role: String = ""
    }

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var lines: [Line]
    var language: String
    var onDone: () -> Void

    @State private var shown = 0
    @State private var typing = false
    @State private var playing: Int?
    @State private var playTask: Task<Void, Never>?
    @State private var played = false

    private var partner: String { lines.first { !$0.mine }?.role ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        Text(L.t("先聽一遍他們怎麼說", "First, listen to how it goes"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondaryLabel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Palette.fill, in: Capsule())
                            .padding(.top, 8)
                        ForEach(lines.prefix(shown)) { line in
                            bubble(line)
                                .id(line.id)
                                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        }
                        if typing { typingBubble.id("typing").transition(.opacity) }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)
                }
                .onChange(of: shown) { _, _ in scrollToEnd(proxy) }
                .onChange(of: typing) { _, _ in scrollToEnd(proxy) }
                .onChange(of: playing) { _, now in
                    guard let now else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { proxy.scrollTo(now, anchor: .center) }
                }
            }
            inputBar
        }
        .task {
            // Read aloud by itself, as the stage's lines always were (Settings → Reading voice).
            guard !AppRuntime.uiTesting, model.settings.speech?.autoReadQuestions ?? true else {
                shown = lines.count
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
            if playTask == nil, !played { togglePlayback() }
        }
        .onDisappear { stopPlayback() }
    }

    /// Who the learner is talking to, like the top of a chat.
    private var chatHeader: some View {
        HStack(spacing: 10) {
            avatar(partner, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(partner.isEmpty ? title : partner)
                    .font(.display(.headline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                // The stage's name is already at the top of the screen.
                Text(L.t("\(lines.count) 句對話", "\(lines.count) lines"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if playTask != nil {
                Label(L.t("對話中", "Talking"), systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    // Adaptive, so it stays legible at night.
                    .foregroundStyle(Palette.known)
                    .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background { PremiumSurface(radius: 18) }
    }

    private func avatar(_ name: String, size: CGFloat) -> some View {
        Text(String(name.prefix(1)))
            .font(.system(size: size * 0.42, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(LinearGradient(colors: [Palette.review.opacity(0.85), Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2))
            .accessibilityHidden(true)
    }

    private func bubble(_ line: Line) -> some View {
        let speaking = playing == line.id
        let shape = UnevenRoundedRectangle(topLeadingRadius: line.mine ? 20 : 6, bottomLeadingRadius: 20,
                                           bottomTrailingRadius: 20, topTrailingRadius: line.mine ? 6 : 20, style: .continuous)
        return HStack(alignment: .top, spacing: 8) {
            if line.mine { Spacer(minLength: 44) } else { avatar(line.role, size: 32) }
            VStack(alignment: .leading, spacing: 4) {
                Text(line.text)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if !line.gloss.isEmpty {
                    Text(line.gloss)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            // The same bubbles as the steps after it (ShadowStepView's chat):
            // the other person on the paper's fill, the learner in clay.
            .background {
                shape.fill(line.mine ? Palette.accent.opacity(0.14) : Palette.fill)
            }
            .overlay { shape.strokeBorder(speaking ? Palette.accent : .clear, lineWidth: 2) }
            .scaleEffect(speaking && !reduceMotion ? 1.02 : 1)
            .animation(reduceMotion ? nil : Motion.press, value: speaking)
            if !line.mine { Spacer(minLength: 44) }
        }
        .accessibilityElement(children: .combine)
    }

    /// The other person typing: three dots.
    private var typingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            avatar(partner, size: 32)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { dot in
                    Circle()
                        .fill(Palette.tertiaryLabel)
                        .frame(width: 8, height: 8)
                        .phaseAnimator([0.3, 1.0]) { content, phase in content.opacity(phase) } animation: { _ in
                            .easeInOut(duration: 0.45).delay(Double(dot) * 0.15)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 0)
        }
    }

    /// Where a chat's input bar would be: play it again, or go on.
    private var inputBar: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: playTask == nil ? (played ? "arrow.counterclockwise" : "play.fill") : "stop.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Palette.accent))
                    .shadow(color: Palette.accent.opacity(0.35), radius: 6, y: 3)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(playTask == nil ? L.t("播放對話", "Play the conversation") : L.t("停止", "Stop"))
            .accessibilityIdentifier("speaking-listen-play")
            Button {
                stopPlayback()
                shown = lines.count
                onDone()
            } label: {
                HStack(spacing: 8) {
                    Text(L.t("我聽懂了", "Got it"))
                    Image(systemName: "arrow.right")
                }
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
            }
            .prominentAction(tint: TodayView.speakingTint)
            .accessibilityIdentifier("speaking-listen-done")
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        let last: AnyHashable = typing ? AnyHashable("typing") : AnyHashable(lines.prefix(shown).last?.id ?? 0)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { proxy.scrollTo(last, anchor: .bottom) }
    }

    private func togglePlayback() {
        if playTask != nil { stopPlayback(); return }
        let preferences = model.settings.speech ?? SpeechPreferences()
        let replay = shown >= lines.count
        playTask = Task { @MainActor in
            for (index, line) in lines.enumerated() {
                guard !Task.isCancelled else { break }
                if !replay, index >= shown {
                    // The other person types for a moment before their line arrives.
                    if !line.mine, !reduceMotion {
                        withAnimation { typing = true }
                        try? await Task.sleep(for: .milliseconds(700))
                        guard !Task.isCancelled else { break }
                        withAnimation { typing = false }
                    }
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) { shown = index + 1 }
                }
                playing = line.id
                Speaker.shared.speak(line.text, language: language, preferences: preferences)
                for _ in 0..<200 {
                    do { try await Task.sleep(for: .milliseconds(150)) } catch { break }
                    if Speaker.shared.activeText != line.text { break }
                }
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(300))
            }
            if !Task.isCancelled { played = true }
            typing = false
            playing = nil
            playTask = nil
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        playing = nil
        typing = false
        Speaker.shared.stop()
        shown = lines.count
    }
}

/// The last step: pick one of today's words and say a sentence of one's
/// own with it. The phone checks the word was said, in a sentence.
struct UseTodaysWordView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// Where the conversation took place, for the cat's line ("a café").
    var place: String
    var wordIds: [String]
    var onDone: (_ wordId: String?, _ used: Bool) -> Void

    @State private var chosen: String?
    @State private var listener = LiveListener()
    @State private var verdict: TodaysWordUse.Verdict?

    private var word: WordEntry? { chosen.flatMap { model.word(id: $0) } }
    private var live: Bool { listener.listening }
    /// This phone cannot turn speech into text: saying something is enough.
    private var uncheckable: Bool { listener.support == .recordOnly }
    private var done: Bool { verdict?.counts == true || (uncheckable && listener.hasRecording) }

    var body: some View {
        VStack(spacing: 14) {
            ScrollView {
                VStack(spacing: 18) {
                    RoutineCatLine(text: catLine, mood: done ? .cheer : verdict == nil ? .thinking : .encourage)
                    HStack(spacing: 10) {
                        ForEach(wordIds, id: \.self) { id in
                            if let entry = model.word(id: id) { wordKey(entry) }
                        }
                    }
                    if let word {
                        example(word)
                            .transition(.opacity)
                        recorder(word)
                    }
                    if let verdict, listener.isFinal {
                        heard(verdict)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                    }
                }
                .padding(.vertical, 4)
            }
            ButtonRow {
                Button {
                    listener.clear()
                    onDone(chosen, false)
                } label: {
                    Text(L.t("跳過", "Skip")).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("speaking-word-skip")
                Button {
                    listener.clear()
                    onDone(chosen, true)
                } label: {
                    Text(L.t("完成", "Done")).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .disabled(!done || listener.busy)
                .accessibilityIdentifier("speaking-word-done")
            }
        }
        .onAppear { if chosen == nil { choose(wordIds.first) } }
        .task { await listener.refresh(language: "en-US") }
        .onDisappear { listener.clear() }
        .onChange(of: listener.isFinal) { _, final in
            guard final, let word else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.25)) {
                verdict = TodaysWordUse.check(heard: listener.text, word: word.word)
            }
        }
        // Stops by itself once the learner stops speaking.
        .task(id: live) {
            guard live else { return }
            while !Task.isCancelled, listener.listening {
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                guard listener.listening else { return }
                if listener.heardVoice, listener.silentFor > 1.5 { listener.stop(); return }
                if listener.support == .live, !listener.text.isEmpty, listener.quietFor > 3 { listener.stop(); return }
                if !listener.heardVoice, listener.text.isEmpty, listener.seconds > 8 { listener.stop(); return }
                if listener.seconds > 25 { listener.stop(); return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { listener.interrupt() }
        }
        .sensoryFeedback(trigger: verdict) { _, new in
            guard model.settings.hapticsEnabled ?? true, let new else { return nil }
            return new.counts ? .success : .warning
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("speaking-word-step")
    }

    private var catLine: String {
        guard let verdict, let word else {
            return L.t("挑一個今天背的字，\n在\(place)用它說一句話。", "Pick one of today's words\nand say a sentence with it at \(place).")
        }
        switch verdict {
        case .used, .usedOtherForm: return L.t("有用到 \(word.word)！今天的字活起來了。", "You used \(word.word)! Today's word came alive.")
        case .tooShort: return L.t("說一整句，不要只說單字。", "A whole sentence, not just the word.")
        case .missing: return L.t("沒聽到 \(word.word)，再說一次？", "Didn't hear \(word.word). Once more?")
        }
    }

    private func choose(_ id: String?) {
        guard let id, id != chosen else { return }
        listener.clear()
        verdict = nil
        withAnimation(reduceMotion ? nil : Motion.reveal) { chosen = id }
        #if DEBUG
        // A simulated take says the example sentence, which has the word in it.
        listener.simulatedText = model.word(id: id)?.example
        #endif
    }

    private func wordKey(_ entry: WordEntry) -> some View {
        let selected = entry.id == chosen
        return Button { choose(entry.id) } label: {
            VStack(spacing: 2) {
                Text(entry.word)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(ChineseDisplay.conciseMeaning(entry.meaningZh))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(selected ? Palette.known.opacity(0.16) : Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Palette.known : Palette.separator, lineWidth: selected ? 2.5 : 1)
            }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("speaking-word-\(entry.id)")
    }

    /// The word's example sentence, the word picked out, as a model to lean on.
    private func example(_ word: WordEntry) -> some View {
        var text = AttributedString(L.t("例如：", "For example: "))
        text.foregroundColor = Palette.secondaryLabel
        if let sentence = Cloze.sentence(for: word) {
            for piece in sentence.pieces {
                switch piece {
                case .text(let part): text += AttributedString(part)
                case .blank:
                    var mark = AttributedString(sentence.answer)
                    mark.foregroundColor = Palette.known
                    mark.font = .body.weight(.bold)
                    text += mark
                }
            }
        } else {
            text += AttributedString(word.example)
        }
        return Text(text)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func recorder(_ word: WordEntry) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if live && !reduceMotion {
                    Circle()
                        .stroke(Palette.miss.opacity(0.3), lineWidth: 3)
                        .frame(width: 112, height: 112)
                        .scaleEffect(1.15 + CGFloat(listener.level) * 0.35)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: listener.level)
                }
                Button {
                    if live {
                        listener.stop()
                    } else {
                        Speaker.shared.stop()
                        verdict = nil
                        listener.start(hints: [word.word])
                    }
                } label: {
                    Image(systemName: live ? "stop.fill" : (listener.hasRecording ? "arrow.counterclockwise" : "mic.fill"))
                        .font(.system(size: 40, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(MicKeyStyle(live: live))
                .disabled(listener.state == .requesting || listener.state == .finishing)
                .accessibilityLabel(live ? L.t("停止", "Stop") : L.t("開始說", "Start speaking"))
                .accessibilityIdentifier("speaking-word-record")
            }
            .frame(height: 130)
            Group {
                if live {
                    Text(L.t("說吧，說完會自動停", "Go ahead; it stops when you're done"))
                } else if listener.state == .finishing {
                    HStack(spacing: 6) { ProgressView(); Text(L.t("聽聽看你說了什麼…", "Listening back…")) }
                } else if listener.hasRecording {
                    Text(L.t("按一下再說一次", "Tap to say it again"))
                } else {
                    Text(L.t("按一下，用 \(word.word) 說一句話", "Tap, then say a sentence with \(word.word)"))
                }
            }
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            if let message = listener.message {
                Text(message).font(.footnote).foregroundStyle(Palette.miss)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// What was heard, with the word marked when it was.
    private func heard(_ verdict: TodaysWordUse.Verdict) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: verdict.counts ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill")
                .font(.title2)
                .foregroundStyle(verdict.counts ? Palette.known : Palette.review)
            VStack(alignment: .leading, spacing: 4) {
                Text(listener.text.isEmpty ? L.t("沒聽清楚，靠近一點再說一次？", "Didn't catch that. Closer, and once more?") : "「\(listener.text)」")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("speaking-word-heard")
                if verdict == .usedOtherForm, let word {
                    Text(L.t("用了 \(word.word) 的變化形，也算！", "A form of \(word.word): that counts!"))
                        .font(.subheadline)
                        .foregroundStyle(Palette.known)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background((verdict.counts ? Palette.known : Palette.review).opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("speaking-word-result")
    }
}
