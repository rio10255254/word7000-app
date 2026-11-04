import SwiftUI
import AVFoundation
import Word7000Core

/// The first step of each word on the speaking path: hear a model sentence,
/// say it back, and see which words (or, in Chinese, which characters and
/// tones) came across. Then on to answering the question in one's own words,
/// where the sentence just said is something to build on.
@MainActor
struct ShadowStepView: View {
    struct Partner {
        let role: String
        let line: String
        /// The line in the learner's own language.
        let gloss: String
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
    /// Called with whether the sentence was said well enough (or said at
    /// all, where this phone cannot turn speech into text).
    let onDone: (_ said: Bool) -> Void

    @State private var recording = SpeakingRecorder()
    @State private var check: ShadowingCheck?
    @State private var showsTranslation = false

    private var language: String { chinese ? "zh-TW" : "en-US" }
    private var live: Bool { recording.state == .recording }
    /// This phone cannot check the take, so saying it is enough.
    private var uncheckable: Bool { recording.support == .unavailable }
    private var said: Bool { check?.passed ?? (uncheckable && recording.hasRecording) }
    private var tried: Bool { check != nil || recording.hasRecording }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 20) {
                    sentenceCard
                    recorderKey
                }
                .padding(.bottom, 12)
            }
            ButtonRow {
                Button { finish() } label: {
                    Text(L.t("跳過", "Skip")).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("shadow-skip")
                Button { finish() } label: {
                    Text(L.t("下一步：回答問題", "Next: answer")).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: said ? Palette.known : Palette.accent)
                .disabled(!tried || recording.busy)
                .accessibilityIdentifier("shadow-next")
            }
        }
        .task { await recording.refresh(language: language) }
        .onAppear {
            #if DEBUG
            // A simulated take says the sentence back.
            recording.simulatedTranscript = sentence
            #endif
        }
        .onDisappear { recording.clear() }
        .onChange(of: recording.state) { old, new in
            if old == .recording, new == .ready, recording.support == .modern || recording.support == .legacy {
                recording.transcribe(hints: [keyword])
            }
        }
        .onChange(of: recording.support) { _, support in
            if support == .modern, recording.state == .ready, recording.hasRecording, recording.transcript == nil {
                recording.transcribe(hints: [keyword])
            }
        }
        .onChange(of: recording.transcript) { _, heard in
            guard let heard else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.3)) {
                check = ShadowingCheck(target: sentence, heard: heard, chinese: chinese)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { recording.interrupt(); Speaker.shared.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in recording.interrupt() }
        .sensoryFeedback(trigger: check?.passed) { _, passed in
            guard model.settings.hapticsEnabled ?? true, let passed else { return nil }
            return passed ? .success : .warning
        }
        .sensoryFeedback(trigger: recording.state) { old, new in
            guard model.settings.hapticsEnabled ?? true else { return nil }
            if new == .recording { return .impact(weight: .medium) }
            if old == .recording { return .impact(weight: .light) }
            return nil
        }
    }

    // MARK: The sentence

    /// What the other person says, as a speech bubble above the reply.
    private func partnerBubble(_ partner: Partner) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(partner.role, systemImage: "person.wave.2.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(partner.line).font(.headline)
                        .accessibilityIdentifier("shadow-partner-line")
                    if chinese {
                        let pinyin = ChineseDisplay.sentencePinyin(partner.line)
                        if !pinyin.isEmpty { Text(pinyin).font(.caption).foregroundStyle(.secondary) }
                    }
                    if showsTranslation, !partner.gloss.isEmpty {
                        Text(partner.gloss).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                SpeakButton(text: partner.line, language: language)
            }
            .padding(12)
            .background(Palette.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var sentenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let partner { partnerBubble(partner) }
            HStack(alignment: .center) {
                Label(partner == nil ? L.t("先跟著說", "Say it after me") : L.t("你可以這樣回，跟著說", "Reply like this: say it after me"),
                      systemImage: partner == nil ? "ear" : "arrowshape.turn.up.left.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                Spacer()
                SpeakButton(text: sentence, language: language)
                    .accessibilityIdentifier("shadow-listen")
            }
            FlowLayout(spacing: chinese ? 2 : 6, lineSpacing: chinese ? 10 : 6) {
                ForEach((check ?? ShadowingCheck(target: sentence, chinese: chinese)).units) { unit in
                    ShadowUnitView(unit: unit, chinese: chinese, showsPinyin: chinese)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sentence)
            .accessibilityIdentifier("shadow-sentence")
            if !translation.isEmpty {
                Button {
                    withAnimation(reduceMotion ? nil : Motion.reveal) { showsTranslation.toggle() }
                } label: {
                    if showsTranslation {
                        Text(translation).font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Label(L.t("看中文意思", "See it in English"), systemImage: "character.bubble")
                            .font(.footnote.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("shadow-translation")
            }
            if let check { result(check) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Metrics.wordCardRadius, padding: 20)
    }

    private func result(_ check: ShadowingCheck) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: check.passed ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(check.passed ? Palette.known : Palette.review)
                    .font(.title3)
                    .symbolEffect(.bounce, value: reduceMotion ? false : check.passed)
                Text(check.passed ? L.t("說得很好！", "Nicely said!") : L.t("差一點，再試一次？", "Almost. One more try?"))
                    .font(.headline)
                Spacer()
                Text("\(Int((check.score * 100).rounded()))%")
                    .font(.display(.headline, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(check.passed ? Palette.known : Palette.review)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("shadow-result")
            // What the colours mean, only when something was not heard as written.
            if check.heardCount < check.units.filter(\.scored).count {
                HStack(spacing: 12) {
                    legend(Palette.known, L.t("聽到了", "Heard"))
                    if check.toneCount > 0 { legend(Palette.review, L.t("聲調不同", "Other tone")) }
                    if check.units.contains(where: { $0.mark == .missed }) { legend(Palette.miss, L.t("沒聽到", "Not heard")) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    // MARK: Recording

    private var recorderKey: some View {
        VStack(spacing: 10) {
            ZStack {
                if live && !reduceMotion {
                    Circle()
                        .stroke(Palette.miss.opacity(0.3), lineWidth: 3)
                        .frame(width: 112, height: 112)
                        .scaleEffect(1.15 + CGFloat(recording.level) * 0.35)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: recording.level)
                }
                Button {
                    if live { recording.stop() } else { Speaker.shared.stop(); recording.start() }
                } label: {
                    Image(systemName: live ? "stop.fill" : (tried ? "arrow.counterclockwise" : "mic.fill"))
                        .font(.system(size: 40, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(MicKeyStyle(live: live))
                .disabled(recording.busy && !live)
                .accessibilityLabel(live ? L.t("停止錄音", "Stop recording") : tried ? L.t("再說一次", "Say it again") : L.t("開始說", "Start speaking"))
                .accessibilityIdentifier("shadow-record")
            }
            .frame(height: 140)
            Group {
                if live {
                    Text(L.t("說完再按一下", "Tap again when you're done"))
                } else if recording.state == .transcribing {
                    HStack(spacing: 6) { ProgressView(); Text(L.t("聽聽看你說了什麼…", "Listening back…")) }
                } else if tried {
                    Text(L.t("按一下再說一次", "Tap to say it again"))
                } else {
                    Text(L.t("聽完後，按一下跟著說", "Listen, then tap and say it"))
                }
            }
            .font(.headline)
            if recording.hasRecording, !live {
                Button {
                    recording.togglePlayback()
                } label: {
                    Label(recording.state == .playing ? L.t("停止", "Stop") : L.t("聽自己的錄音", "Hear yourself"),
                          systemImage: recording.state == .playing ? "stop.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .disabled(recording.busy && recording.state != .playing)
                .accessibilityIdentifier("shadow-play")
            }
            if let message = recording.message {
                Text(message).font(.footnote).foregroundStyle(Palette.miss)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if uncheckable, recording.hasRecording {
                Text(L.t("這支手機無法自動比對，聽聽自己的錄音，和示範比較看看。", "This iPhone can't check it. Play your take back and compare it with the model."))
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func finish() {
        recording.interrupt()
        Speaker.shared.stop()
        onDone(said)
    }
}

/// One word, or one Chinese character with its pinyin, coloured by how it came across.
private struct ShadowUnitView: View {
    let unit: ShadowingCheck.Unit
    let chinese: Bool
    let showsPinyin: Bool

    private var color: Color {
        switch unit.mark {
        case .none: Palette.ink
        case .heard: Palette.known
        case .tone: Palette.review
        case .missed: Palette.miss
        }
    }

    var body: some View {
        if chinese {
            VStack(spacing: 1) {
                Text(pinyin)
                    .font(.caption2.weight(unit.mark == nil ? .regular : .semibold))
                    .foregroundStyle(unit.mark == nil ? Palette.secondaryLabel : color)
                    .lineLimit(1)
                    .fixedSize()
                Text(unit.text)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(unit.scored ? color : Palette.secondaryLabel)
            }
            .frame(minWidth: unit.scored ? 30 : 0)
            // Full-width punctuation sits close to the character before it.
            .padding(.horizontal, unit.scored ? 0 : -6)
        } else {
            Text(unit.text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .underline(unit.mark == .missed, color: Palette.miss)
        }
    }

    /// The expected reading, or the one heard instead when only the tone differed.
    private var pinyin: String {
        guard showsPinyin, unit.scored else { return " " }
        if case .tone(let heard) = unit.mark { return heard }
        return unit.pinyin
    }
}

/// Lays children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

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
