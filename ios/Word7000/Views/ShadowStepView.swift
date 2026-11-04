import SwiftUI
import AVFoundation
import Word7000Core

/// The first step of each item on the speaking path: hear a model sentence,
/// then say it back. Words (in Chinese, characters) light up as they are
/// heard; once all are, or after a pause, listening stops by itself and shows
/// what came across. A sentence said well moves on after a short countdown
/// that any touch on the sentence cancels.
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

    @State private var listener = LiveListener()
    @State private var check: ShadowingCheck?
    @State private var showsTranslation = false
    /// Counting down to the next step after a sentence said well.
    @State private var advancing = false

    private var language: String { chinese ? "zh-TW" : "en-US" }
    private var live: Bool { listener.listening }
    /// This phone cannot turn speech into text, so saying it is enough.
    private var uncheckable: Bool { listener.support == .recordOnly }
    private var said: Bool { check?.passed ?? (uncheckable && listener.hasRecording) }
    private var tried: Bool { check != nil || listener.hasRecording }
    /// How long the result shows before moving on by itself.
    private var countdown: Duration { AppRuntime.uiTesting ? .seconds(4) : .milliseconds(1600) }

    /// While listening only what was heard is coloured; the rest waits.
    private var shownUnits: [ShadowingCheck.Unit] {
        if let check, listener.isFinal { return check.units }
        let units = (check ?? ShadowingCheck(target: sentence, chinese: chinese)).units
        return units.map { unit in
            var shown = unit
            if unit.mark != .heard { shown.mark = nil }
            return shown
        }
    }

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
                .overlay(alignment: .leading) { countdownFill }
                .disabled(!tried || listener.busy)
                .accessibilityIdentifier("shadow-next")
            }
        }
        .task { await listener.refresh(language: language) }
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
            if !listener.text.isEmpty {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.3)) {
                    check = ShadowingCheck(target: sentence, heard: listener.text, chinese: chinese)
                }
            } else if listener.support == .live {
                withAnimation { check = ShadowingCheck(target: sentence, heard: "", chinese: chinese) }
            }
            if said { advancing = true }
        }
        // Stops by itself: everything heard, or a pause after speaking.
        .task(id: live) {
            guard live else { return }
            while !Task.isCancelled, listener.listening {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                let complete = check.map { $0.heardCount == $0.scoredCount && $0.scoredCount > 0 } ?? false
                if complete, listener.quietFor > 0.35 { listener.stop(); return }
                if !listener.text.isEmpty, listener.quietFor > 2.2 { listener.stop(); return }
                if listener.text.isEmpty, listener.quietFor > 8 { listener.stop(); return }
            }
        }
        .task(id: advancing) {
            guard advancing else { return }
            do { try await Task.sleep(for: countdown) } catch { return }
            guard advancing else { return }
            finish()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { advancing = false; listener.interrupt(); Speaker.shared.stop() }
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
                    let pinyin = ChineseDisplay.sentencePinyin(partner.line)
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
            SpeakButton(text: partner.line, language: language)
                .simultaneousGesture(TapGesture().onEnded { advancing = false })
            Spacer(minLength: 24)
        }
    }

    /// The sentence to say, large: on the right like one's own message in a
    /// role-play, plain otherwise. Tapping it shows the translation.
    @ViewBuilder
    private var replyBlock: some View {
        if partner != nil {
            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 24)
                replyKeys
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
            FlowLayout(spacing: chinese ? 2 : 7, lineSpacing: chinese ? 10 : 6) {
                ForEach(shownUnits) { unit in
                    ShadowUnitView(unit: unit, chinese: chinese, showsPinyin: chinese)
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
                .simultaneousGesture(TapGesture().onEnded { advancing = false })
                .accessibilityIdentifier("shadow-listen")
            if !translation.isEmpty {
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
    }

    private func toggleTranslation() {
        advancing = false
        guard !translation.isEmpty || !(partner?.gloss ?? "").isEmpty else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { showsTranslation.toggle() }
    }

    private var sentenceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let partner { partnerBubble(partner) }
            replyBlock
            if let check, listener.isFinal { result(check) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Metrics.wordCardRadius, padding: 18)
    }

    private func result(_ check: ShadowingCheck) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: check.passed ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(check.passed ? Palette.known : Palette.review)
                    .font(.title3)
                    .symbolEffect(.bounce, value: reduceMotion ? false : check.passed)
                Text(check.passed ? L.t("說得很好！", "Nicely said!") : L.t("差一點，再試一次？", "Almost. One more try?"))
                    .font(.headline)
                Spacer()
                Text("\(Int((check.score * 100).rounded()))%")
                    .font(.display(.title3, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(check.passed ? Palette.known : Palette.review)
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
        }
        .padding(.top, 4)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
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
                    Button {
                        advancing = false
                        if live { listener.stop() } else { Speaker.shared.stop(); check = nil; listener.start() }
                    } label: {
                        Image(systemName: live ? "stop.fill" : (tried ? "arrow.counterclockwise" : "mic.fill"))
                            .font(.system(size: 40, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(MicKeyStyle(live: live))
                    .disabled(listener.state == .requesting || listener.state == .finishing)
                    .accessibilityLabel(live ? L.t("停止", "Stop") : tried ? L.t("再說一次", "Say it again") : L.t("開始說", "Start speaking"))
                    .accessibilityIdentifier("shadow-record")
                }
                .frame(height: 136)
                // Balances the play key so the big key stays centred.
                Color.clear.frame(width: 48, height: 48)
            }
            Group {
                if live {
                    Text(listener.text.isEmpty ? L.t("請說…", "Go ahead…") : L.t("繼續說，說完會自動停", "Keep going; it stops when you're done"))
                } else if listener.state == .finishing {
                    HStack(spacing: 6) { ProgressView(); Text(L.t("聽聽看你說了什麼…", "Listening back…")) }
                } else if advancing {
                    Text(L.t("馬上進入下一步", "On to the next step"))
                } else if tried {
                    Text(L.t("按一下再說一次", "Tap to say it again"))
                } else {
                    Text(L.t("聽完後，按一下跟著說", "Listen, then tap and say it"))
                }
            }
            .font(.headline)
            .contentTransition(.opacity)
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

    private var playKey: some View {
        Button {
            advancing = false
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

    private func finish() {
        advancing = false
        listener.interrupt()
        Speaker.shared.stop()
        onDone(said)
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
                    .font(.caption.weight(unit.mark == nil ? .regular : .semibold))
                    .foregroundStyle(unit.mark == nil ? Palette.secondaryLabel : color)
                    .lineLimit(1)
                    .fixedSize()
                Text(unit.text)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(unit.scored ? color : Palette.secondaryLabel)
            }
            .frame(minWidth: unit.scored ? 34 : 0)
            // Full-width punctuation sits close to the character before it.
            .padding(.horizontal, unit.scored ? 0 : -6)
        } else {
            Text(unit.text)
                .font(.title2.weight(.semibold))
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
