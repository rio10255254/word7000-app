import AVFoundation
import SwiftUI
import Word7000Core

/// The first launch, as three small scenes on the desk with the cat: what to
/// learn, how much a day, and which of a few words are already known. Each is
/// one tap or a few; the known words set where new words start. When the
/// iPhone only has a standard voice for what is learned, a fourth scene shows
/// how to download the natural one, which apps cannot do themselves.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .hello
    @State private var forward = true
    @State private var mode: StudyMode = .english
    @State private var target = 20
    @State private var known: Set<String> = []
    @State private var placement: [WordEntry] = []
    @State private var hop = 0
    /// The iPhone has only a standard voice for the language learned, so the
    /// last scene shows how to get the natural one. Settled before that scene,
    /// so the steps do not change under the learner while they download it.
    @State private var voicePlanned = false
    /// Whether the first practice starts straight away (or the bank is
    /// looked around first), chosen on the words scene.
    @State private var practice = true
    var finish: (_ mode: StudyMode, _ target: Int, _ knownIds: [String], _ practice: Bool) -> Void

    enum Step: Int, CaseIterable { case hello, goal, words, voice }

    private var steps: [Step] { Step.allCases.filter { $0 != .voice || voicePlanned } }
    private var voiceLanguage: String { mode == .english ? "en-US" : "zh-TW" }

    /// The interface speaks the learner's own language once they have chosen.
    private var chinese: Bool { mode == .english }
    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { proxy in
                ScrollView {
                    Group {
                        switch step {
                        case .hello: hello
                        case .goal: goal
                        case .words: words
                        case .voice:
                            VoiceStep(language: voiceLanguage, chinese: chinese, hop: hop) {
                                finish(mode, target, Array(known), practice)
                            }
                        }
                    }
                    .id(step)
                    .transition(transition)
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 560)
                    // Each scene sits a little above the middle of the screen
                    // rather than leaving the bottom half empty.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height * 0.88)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background { AmbientBackground() }
        .sensoryFeedback(.selection, trigger: target)
        .sensoryFeedback(.selection, trigger: known)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .onAppear {
            if placement.isEmpty { placement = placementWords(for: mode) }
        }
        .task(id: mode) {
            await Speaker.shared.refreshVoices()
            guard step != .voice else { return }
            voicePlanned = SpeechVoiceSelection.canSoundBetter(Speaker.shared.voices, language: voiceLanguage,
                                                               enhancedQuality: AVSpeechSynthesisVoiceQuality.enhanced.rawValue)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            if !reduceMotion { hop += 1 }
        }
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    private func go(_ next: Step) {
        forward = next.rawValue > step.rawValue
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.4)) { step = next }
        if !reduceMotion { hop += 1 }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) { go(previous) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .opacity(step == .hello ? 0 : 1)
            .disabled(step == .hello)
            .accessibilityLabel(text("上一步", "Back"))
            Spacer()
            HStack(spacing: 6) {
                ForEach(steps, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Palette.accent : Palette.fill)
                        .frame(width: item == step ? 22 : 8, height: 8)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("第 \(step.rawValue + 1) 步，共 \(steps.count) 步", "Step \(step.rawValue + 1) of \(steps.count)"))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .tint(Palette.accent)
    }

    // MARK: 1. What to learn

    private var hello: some View {
        VStack(spacing: 22) {
            VStack(spacing: 4) {
                Mascot(mood: .smug, size: 112, hop: hop)
                    .popIn()
                MascotBubble(text: "嗨，我是傻貓。\nHi, I'm Silly Cat.", pointing: .top)
                    .entrance(1)
            }
            Text("你想學什麼？\nWhat do you want to learn?")
                .font(.display(.title2, weight: .bold))
                .multilineTextAlignment(.center)
                .entrance(2)
            HStack(alignment: .top, spacing: 14) {
                LanguageChoice(title: "English", subtitle: "我想學英文", samples: ["brave", "journey", "bright"],
                               paper: .graph, tilt: -1.2) { choose(.english) }
                    .accessibilityIdentifier("welcome-learn-english")
                LanguageChoice(title: "中文", subtitle: "I want to learn Chinese", samples: ["勇敢", "旅程", "明亮"],
                               paper: .peach, tilt: 1.1) { choose(.chinese) }
                    .accessibilityIdentifier("welcome-learn-chinese")
            }
            .entrance(3)
        }
    }

    /// The check words come from the bank of what is being learned.
    private func placementWords(for language: StudyMode) -> [WordEntry] {
        let chinese = language == .chinese && !model.chineseCoreWords.isEmpty
        return Placement.words(from: chinese ? model.chineseCoreWords : model.englishCoreWords,
                               seed: model.settings.deviceSourceId, chinese: chinese)
    }

    private func choose(_ language: StudyMode) {
        mode = language
        placement = placementWords(for: language)
        known = []
        go(.goal)
    }

    // MARK: 2. How much a day

    private static let goals: [(count: Int, zh: String, en: String, paper: PaperKind, tilt: Double)] = [
        (10, "輕鬆", "Easy", .sage, -2), (20, "剛好", "Steady", .mustard, 1.5),
        (30, "認真", "Serious", .peach, 1), (50, "拼了", "All in", .graph, -1.5),
    ]

    private var goal: some View {
        VStack(spacing: 22) {
            CatLine(mood: .thinking, hop: hop,
                    text: text("一天想背幾個字？之後隨時能改。", "How many words a day? You can change it any time."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(Self.goals, id: \.count) { item in
                    StickyNote(count: item.count, label: text(item.zh, item.en), unit: text("個／天", "a day"),
                               paper: item.paper, tilt: item.tilt, selected: target == item.count) {
                        withAnimation(reduceMotion ? nil : Motion.pop) { target = item.count }
                    }
                    .accessibilityIdentifier("welcome-goal-\(item.count)")
                }
            }
            Button { go(.words) } label: {
                Label(text("下一步", "Next"), systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("welcome-next")
        }
    }

    // MARK: 3. What you already know

    private var words: some View {
        VStack(spacing: 20) {
            CatLine(mood: known.isEmpty ? .idle : .happy, hop: hop, text: reaction)
                .animation(reduceMotion ? nil : Motion.reveal, value: reaction)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(Array(placement.enumerated()), id: \.element.id) { index, word in
                    WordTag(text: WordFace(word, mode: mode).prompt, known: known.contains(word.id), seed: index) {
                        withAnimation(reduceMotion ? nil : Motion.pop) {
                            if known.contains(word.id) { known.remove(word.id) } else { known.insert(word.id) }
                        }
                    }
                    .accessibilityIdentifier("welcome-word-\(word.id)")
                }
            }
            VStack(spacing: 10) {
                Button { leaveWords(practice: true) } label: {
                    Label(text("開始，先背 5 個", "Start with 5 words"), systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-start")
                Button(text("先逛逛字庫", "Look around first")) { leaveWords(practice: false) }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcome-skip")
            }
            .padding(.top, 4)
        }
    }

    /// On to the voice scene when it is wanted; otherwise that was the last.
    private func leaveWords(practice: Bool) {
        self.practice = practice
        if voicePlanned { go(.voice) } else { finish(mode, target, Array(known), practice) }
    }

    /// The cat's take on how many were tapped, so the tapping feels heard.
    private var reaction: String {
        switch known.count {
        case 0: text("這些字你認得哪幾個？點一下就好，不認得也沒關係。", "Which of these do you know? Just tap them. Not knowing is fine.")
        case 1...2: text("好，有底子。我從適合你的開始。", "Good, there's a base. I'll start where it suits you.")
        case 3...5: text("不錯嘛，太簡單的我就少給一點。", "Not bad. I'll go easy on the easy ones.")
        default: text("……好啦你很強，我把難的拿出來。", "…Fine, you're good. Out come the hard ones.")
        }
    }
}

// MARK: 4. A natural voice

/// How to download the iPhone's natural voice for what is learned (an app
/// cannot download it), the voice as it sounds now, and the switch noticed
/// the moment iOS has it: a tick, and the cat says hello in the new voice.
private struct VoiceStep: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var language: String
    var chinese: Bool
    var hop: Int
    var done: () -> Void
    @State private var switched = 0

    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    private var preferences: SpeechPreferences { model.settings.speech ?? SpeechPreferences() }
    private var learningChinese: Bool { language.hasPrefix("zh") }
    private var upgraded: Bool {
        !SpeechVoiceSelection.canSoundBetter(Speaker.shared.voices, language: language,
                                             enhancedQuality: AVSpeechSynthesisVoiceQuality.enhanced.rawValue)
    }
    private var sample: String {
        learningChinese ? "很高興認識你，我們一起學幾個字吧。" : "Nice to meet you. Let's learn a few words together."
    }

    var body: some View {
        VStack(spacing: 20) {
            CatLine(mood: upgraded ? .cheer : .happy, hop: hop + switched,
                    text: upgraded ? text("換好了！聽聽看，是不是像真人多了？", "Done! Have a listen: more like a real person, right?")
                                   : text("最後一件事：我的聲音可以更像真人。iPhone 的好聲音要你自己下載一次，免費。",
                                          "One last thing: I can sound much more like a real person. The iPhone's natural voice is a free download you do once."))
            if upgraded { switchedCard.transition(.scale(scale: 0.92).combined(with: .opacity)) } else { stepsCard }
            Button {
                Speaker.shared.speak(sample, language: language, preferences: preferences)
            } label: {
                Label(upgraded ? text("再聽一次", "Hear it again") : text("聽聽現在的聲音", "Hear the voice now"),
                      systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .secondaryAction()
            .accessibilityIdentifier("welcome-voice-preview")
            VStack(spacing: 10) {
                if upgraded {
                    Button(action: done) {
                        Label(text("開始", "Start"), systemImage: "arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("welcome-voice-done")
                } else {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label(text("打開設定", "Open Settings"), systemImage: "gear")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("welcome-voice-settings")
                    Button(text("先開始，晚點再下載", "Start now, download later"), action: done)
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("welcome-voice-done")
                }
            }
            .padding(.top, 4)
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: upgraded)
        // Back from Settings: look again, in case iOS has not said so yet.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await Speaker.shared.refreshVoices(fresh: true) } }
        }
        .onChange(of: upgraded) { _, now in
            guard now else { return }
            switched += 1
            Speaker.shared.stop()
            Speaker.shared.speak(sample, language: language, preferences: preferences)
        }
        .sensoryFeedback(.success, trigger: switched) { _, _ in model.settings.hapticsEnabled ?? true }
        .onDisappear { Speaker.shared.stop() }
    }

    /// The three steps, with the voice named as Settings lists it.
    private var stepsCard: some View {
        let lines = [
            text("打開 iPhone「設定」→「輔助使用」→「朗讀內容」→「聲音」",
                 "Open iPhone Settings → Accessibility → Spoken Content → Voices"),
            learningChinese
                ? text("點「中文（台灣）」→「美佳」，下載「增強」版本", "Tap Chinese (Taiwan) → Meijia and download the Enhanced version")
                : text("點「英文」→「Ava」，下載最大的那個（優質）", "Tap English → Ava and download the biggest one (Premium)"),
            text("回到這裡就好，下載完會自動換上", "Come back here; it switches by itself once downloaded"),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Palette.accent, in: Circle())
                    Text(line)
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            Text(text("檔案有點大，建議連 Wi-Fi。下載在背景進行，可以先開始學。「打開設定」會先到單字貓的頁面，按左上角返回到最上層。",
                      "It's a big file, so Wi-Fi is best. It downloads in the background, so you can start meanwhile. Open Settings lands on WordCat's page; go back at the top left to the main list."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcome-voice-steps")
    }

    /// The natural voice is in: which one now reads.
    private var switchedCard: some View {
        let name = Speaker.shared.selectedVoice(language: language, preferences: preferences)?.name
            ?? SpeechVoiceSelection.recommendedVoice(language: language).name
        return HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(Palette.known)
            VStack(alignment: .leading, spacing: 2) {
                Text(text("已經換成自然的聲音", "Now using the natural voice"))
                    .font(.headline)
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Palette.known.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcome-voice-switched")
    }
}

/// The cat with what it says beside it.
private struct CatLine: View {
    var mood: Mascot.Mood
    var hop: Int
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Mascot(mood: mood, size: 72, hop: hop)
            MascotBubble(text: text, pointing: .leading)
                .padding(.leading, 6)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
    }
}

/// A language to learn, as a card cut from its own paper with a few sample
/// words on it.
private struct LanguageChoice: View {
    @Environment(\.appStyle) private var appStyle
    var title: String
    var subtitle: String
    var samples: [String]
    var paper: PaperKind
    var tilt: Double
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.display(.title, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 4) {
                    ForEach(samples, id: \.self) { sample in
                        Text(sample)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Palette.accent.opacity(0.12), in: Capsule())
                    }
                }
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background { surface }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 4, seed: title.count + 3))
                .overlay(alignment: .top) { TapeStrip(width: 46, angle: tilt * 4).offset(y: -10) }
                .rotationEffect(.degrees(tilt))
        } else {
            PremiumSurface(radius: 24)
        }
    }
}

/// A daily goal on a sticky note; the chosen one is pressed flat and stamped.
private struct StickyNote: View {
    @Environment(\.appStyle) private var appStyle
    var count: Int
    var label: String
    var unit: String
    var paper: PaperKind
    var tilt: Double
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.displaySize(36, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(unit).font(.caption).foregroundStyle(.secondary)
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selected ? Palette.accent : Palette.ink.opacity(0.75))
                    .padding(.top, 2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background { surface }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.accent)
                        .background(Circle().fill(.white).padding(3))
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .rotationEffect(.degrees(selected ? 0 : tilt))
            .scaleEffect(selected ? 1.04 : 1)
            // The chosen note stands out; the others step back, so a bright
            // paper (the mustard 20) never reads as the choice.
            .saturation(selected ? 1 : 0.55)
            .opacity(selected ? 1 : 0.82)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
                .shadow(color: .black.opacity(selected ? 0.16 : 0.06), radius: selected ? 8 : 2, y: selected ? 4 : 1)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? Palette.accent.opacity(0.14) : Palette.surface)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
    }
}

/// A word on a small index card; tapped, it gets a green "known" stamp.
private struct WordTag: View {
    @Environment(\.appStyle) private var appStyle
    var text: String
    var known: Bool
    var seed: Int
    var action: () -> Void

    private var tilt: Double { [-2.0, 1.5, -1.0, 2.0, -1.5, 1.0, -2.5, 1.8, -0.8][seed % 9] }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.display(.headline, weight: .semibold))
                .foregroundStyle(known ? Palette.known : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background { surface }
                .overlay(alignment: .bottomTrailing) {
                    if known {
                        StampMark(color: Palette.known, size: 30, angle: -14) {
                            Image(systemName: "checkmark").font(.caption.weight(.heavy))
                        }
                        .offset(x: 6, y: 8)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                    }
                }
                .rotationEffect(.degrees(known ? 0 : tilt))
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(text)
        .accessibilityAddTraits(known ? .isSelected : [])
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: known ? .sage : .ivory)
                .overlay(alignment: .top) { Rectangle().fill(Collage.margin.opacity(0.6)).frame(height: 1.5).padding(.top, 12) }
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(known ? Palette.known.opacity(0.14) : Palette.surface)
                .shadow(color: .black.opacity(0.07), radius: 6, y: 2)
        }
    }
}
