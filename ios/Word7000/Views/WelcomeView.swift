import SwiftUI
import Word7000Core

/// The first launch, as three small scenes on the desk with the cat: what to
/// learn, how much a day, and which of a few words are already known. Each is
/// one tap or a few; the known words set where new words start.
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
    var finish: (_ mode: StudyMode, _ target: Int, _ knownIds: [String], _ practice: Bool) -> Void

    enum Step: Int, CaseIterable { case hello, goal, words }

    /// The interface speaks the learner's own language once they have chosen.
    private var chinese: Bool { mode == .english }
    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                Group {
                    switch step {
                    case .hello: hello
                    case .goal: goal
                    case .words: words
                    }
                }
                .id(step)
                .transition(transition)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { AmbientBackground() }
        .sensoryFeedback(.selection, trigger: target)
        .sensoryFeedback(.selection, trigger: known)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .onAppear {
            if placement.isEmpty { placement = Placement.words(from: model.coreWords, seed: model.settings.deviceSourceId) }
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
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Palette.accent : Palette.fill)
                        .frame(width: item == step ? 22 : 8, height: 8)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("第 \(step.rawValue + 1) 步，共 3 步", "Step \(step.rawValue + 1) of 3"))
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
                MascotBubble(text: "嗨，我是小笨貓。\nHi, I'm Silly Cat.", pointing: .top)
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

    private func choose(_ language: StudyMode) {
        mode = language
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
                Button { finish(mode, target, Array(known), true) } label: {
                    Label(text("開始，先背 5 個", "Start with 5 words"), systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-start")
                Button(text("先逛逛字庫", "Look around first")) { finish(mode, target, Array(known), false) }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcome-skip")
            }
            .padding(.top, 4)
        }
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
