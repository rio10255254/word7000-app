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

/// The four steps of a speaking stage, as chips.
struct SpeakingStepStrip: View {
    var step: SpeakingStep

    private enum ChipState { case done, now, later }

    var body: some View {
        HStack(spacing: 5) {
            chip("ear", L.t("聽", "Listen"), state(.listen))
            chip("repeat", L.t("跟讀", "Repeat"), state(.shadow))
            chip("bubble.left", L.t("回答", "Answer"), state(.answer))
            chip("sparkles", L.t("用今天的字", "Use a word"), state(.useWord))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("聽、跟讀、回答、用今天的字", "Listen, repeat, answer, use today's word"))
        .accessibilityIdentifier("speaking-steps")
    }

    /// Repeating and answering take turns through the stage, so neither is
    /// ticked until the turns are over.
    private func state(_ chip: SpeakingStep) -> ChipState {
        if chip == step { return .now }
        switch (chip, step) {
        case (.listen, _): return step > .listen ? .done : .later
        case (.shadow, .answer), (.answer, .shadow): return .later
        default: return chip < step ? .done : .later
        }
    }

    private func chip(_ icon: String, _ title: String, _ state: ChipState) -> some View {
        HStack(spacing: 4) {
            Image(systemName: state == .done ? "checkmark" : icon)
                .font(.caption.weight(.heavy))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(state == .now ? Color.white : state == .done ? Palette.known : Palette.secondaryLabel)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(state == .now ? TodayView.speakingTint : state == .done ? Palette.known.opacity(0.16) : Palette.fill, in: Capsule())
    }
}

/// The first step: the whole conversation of the stage, read aloud line by
/// line, the English big and the translation under it.
struct SpeakingListenView: View {
    struct Line: Identifiable, Equatable {
        let id: Int
        let text: String
        let gloss: String
        /// Said by the learner's side (on the right).
        let mine: Bool
    }

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var lines: [Line]
    var language: String
    var onDone: () -> Void

    @State private var playing: Int?
    @State private var playTask: Task<Void, Never>?
    @State private var played = false

    var body: some View {
        VStack(spacing: 14) {
            RoutineCatLine(text: L.t("\(title)\n先聽一遍他們怎麼說。", "\(title)\nFirst, listen to how it goes."),
                           mood: played ? .happy : .thinking)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(lines) { line in
                            bubble(line).id(line.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: playing) { _, now in
                    guard let now else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { proxy.scrollTo(now, anchor: .center) }
                }
            }
            VStack(spacing: 6) {
                Button(action: togglePlayback) {
                    Image(systemName: playTask == nil ? (played ? "arrow.counterclockwise" : "play.fill") : "stop.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(Palette.accent))
                        .shadow(color: Palette.accent.opacity(0.35), radius: 10, y: 5)
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(playTask == nil ? L.t("播放對話", "Play the conversation") : L.t("停止", "Stop"))
                .accessibilityIdentifier("speaking-listen-play")
                Text(playTask == nil ? (played ? L.t("再聽一次", "Again") : L.t("播放對話", "Play it")) : L.t("播放中…", "Playing…"))
                    .font(.headline)
                    .foregroundStyle(Palette.accent)
            }
            Button {
                stopPlayback()
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
            .padding(.bottom, 4)
            .accessibilityIdentifier("speaking-listen-done")
        }
        .task {
            // Read aloud by itself, as the stage's lines always were (Settings → Reading voice).
            guard !AppRuntime.uiTesting, model.settings.speech?.autoReadQuestions ?? true else { return }
            try? await Task.sleep(for: .milliseconds(700))
            if playTask == nil, !played { togglePlayback() }
        }
        .onDisappear { stopPlayback() }
    }

    private func bubble(_ line: Line) -> some View {
        let speaking = playing == line.id
        return HStack {
            if line.mine { Spacer(minLength: 36) }
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
            .padding(.vertical, 12)
            .background(line.mine ? TodayView.speakingTint.opacity(0.16) : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(speaking ? Palette.accent : .clear, lineWidth: 2)
            }
            .scaleEffect(speaking && !reduceMotion ? 1.02 : 1)
            .animation(reduceMotion ? nil : Motion.press, value: speaking)
            if !line.mine { Spacer(minLength: 36) }
        }
        .accessibilityElement(children: .combine)
    }

    private func togglePlayback() {
        if playTask != nil { stopPlayback(); return }
        let preferences = model.settings.speech ?? SpeechPreferences()
        playTask = Task { @MainActor in
            for line in lines {
                guard !Task.isCancelled else { break }
                playing = line.id
                Speaker.shared.speak(line.text, language: language, preferences: preferences)
                // Until the line has been said (or stopped), then a breath.
                for _ in 0..<200 {
                    do { try await Task.sleep(for: .milliseconds(150)) } catch { break }
                    if Speaker.shared.activeText != line.text { break }
                }
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(350))
            }
            if !Task.isCancelled { played = true }
            playing = nil
            playTask = nil
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        playing = nil
        Speaker.shared.stop()
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
