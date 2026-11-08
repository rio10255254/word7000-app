import SwiftUI
import UIKit

// WordCat Next: Silly Cat everywhere. Now and then it pokes its head in from
// the side or pops up from the bottom of whatever page you are on, says
// something rude, and ducks away: on switching tabs, after a while doing
// nothing, and to mock a wrong answer. Tap it and it gets smacked for its
// trouble. It never sits over anything for long, takes no touches except on
// itself, and stays away under Reduce Motion and the UI tests.

/// Taps you can feel, for places that have no model at hand (button styles):
/// follows Settings → Haptic feedback.
enum Feel {
    nonisolated(unsafe) static var enabled = true

    @MainActor static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light, intensity: CGFloat = 0.7) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }
}

/// When and where the cat shows up.
@MainActor @Observable
final class CatPeek {
    static let shared = CatPeek()

    enum Side: CaseIterable { case leading, trailing, bottom }

    struct Visit: Identifiable, Equatable {
        let id = UUID()
        var line: String
        var mood: Mascot.Mood
        var side: Side
        /// Where along its edge, 0 to 1.
        var spot: CGFloat
        /// How long it stays.
        var seconds: Double
    }

    private(set) var visit: Visit?
    @ObservationIgnored private var lastVisit = Date.distantPast
    @ObservationIgnored private var lastLine: String?

    private var allowed: Bool {
        !AppRuntime.uiTesting && !UIAccessibility.isReduceMotionEnabled
    }

    /// Pops in with one of `lines`, with probability `chance`, at most once
    /// every `gap` seconds (unless forced).
    func poke(_ lines: [String], mood: Mascot.Mood = .smug, chance: Double = 1, gap: Double = 25, force: Bool = false) {
        guard allowed, visit == nil, !lines.isEmpty else { return }
        guard force || Date().timeIntervalSince(lastVisit) > gap else { return }
        guard force || Double.random(in: 0..<1) < chance else { return }
        var line = lines.randomElement() ?? lines[0]
        if line == lastLine, let other = lines.first(where: { $0 != lastLine }) { line = other }
        lastLine = line
        lastVisit = Date()
        visit = Visit(line: line, mood: mood, side: Side.allCases.randomElement() ?? .trailing,
                      spot: .random(in: 0.28...0.62), seconds: max(2.6, min(4.5, Double(line.count) * 0.12)))
    }

    @ObservationIgnored private var rightInARow = 0

    /// Hears every answer (through the sound it makes): a miss is mocked now
    /// and then, a good run grudgingly praised.
    func noteAnswer(correct: Bool) {
        if correct {
            rightInARow += 1
            if rightInARow % 6 == 0 { poke(Self.streakLines, mood: .happy, chance: 0.6, gap: 30) }
        } else {
            rightInARow = 0
            poke(Self.missLines, mood: .cheeky, chance: 0.3, gap: 25)
        }
    }

    func leave(_ id: UUID) {
        if visit?.id == id { visit = nil }
    }

    // MARK: What it says

    /// On switching to a tab.
    static func tabLines(_ tab: AppTab) -> [String] {
        switch tab {
        case .today: [
            L.t("回來啦？單字可不會自己背。", "Back? The words won't learn themselves."),
            L.t("今天的份做完了沒？我在看喔。", "Done today's lot yet? I'm watching."),
            L.t("又來滑手機？那順便背幾個。", "Scrolling again? Learn a few while you're here."),
        ]
        case .practice: [
            L.t("選一個啦，選擇困難喔？", "Pick one. Can't decide?"),
            L.t("練口說啦，不要只會看。", "Try speaking. Looking isn't practising."),
            L.t("考試題型？你確定你準備好了？", "Exam questions? You sure about that?"),
        ]
        case .words: [
            L.t("這麼多字，你背得完嗎？", "That many words. Can you, though?"),
            L.t("找字喔？找到了也要記得啊。", "Looking one up? Remember it this time."),
            L.t("收藏不等於學會，懂？", "Saving a word isn't learning it."),
        ]
        case .me: [
            L.t("在看自己的戰績？嗯……不多嘛。", "Checking your stats? Hm. Not many."),
            L.t("格子要塗滿才好看喔。", "Those squares look better filled in."),
            L.t("設定調來調去，單字還是要背。", "Tweak away. The words still need learning."),
        ]
        }
    }

    /// After a while of doing nothing.
    static var idleLines: [String] { [
        L.t("發呆喔？", "Daydreaming?"),
        L.t("我數到三，你就去背單字。三。", "I'll count to three and you start. Three."),
        L.t("我好無聊，你也是吧。來背字。", "I'm bored. You too. Words?"),
        L.t("盯著我看也不會變聰明。", "Staring at me won't make you smarter."),
        L.t("喵。翻譯：快去練習。", "Meow. Translation: go practise."),
    ] }

    /// On a wrong answer.
    static var missLines: [String] { [
        L.t("噗。", "Pfft."),
        L.t("剛剛那個……認真？", "That one… seriously?"),
        L.t("沒關係，我會記住的。永遠。", "It's fine. I'll remember. Forever."),
        L.t("錯得很有自信喔。", "Wrong, but with confidence."),
        L.t("我假裝沒看到。", "I'll pretend I didn't see that."),
    ] }

    /// On a run of right answers.
    static var streakLines: [String] { [
        L.t("欸？可以喔。", "Huh. Not bad."),
        L.t("今天吃錯藥？這麼厲害。", "Who are you and what did you do with my student?"),
        L.t("好啦，算你厲害。一點點。", "Fine, you're good. A little."),
    ] }

    /// When it is tapped while peeking.
    static var smackLines: [String] { [
        L.t("幹嘛啦！", "Hey!"),
        L.t("打我不會加分。", "Hitting me isn't worth points."),
        L.t("好啦好啦，我走。", "Fine, fine, I'm going."),
        L.t("記住了。", "Noted."),
    ] }
}

/// Shows the cat's visits over a page. Put it over every full page: the tabs
/// and each practice.
struct CatPeekHost: View {
    @Environment(AppModel.self) private var model
    private let peek = CatPeek.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let visit = peek.visit {
                    CatPeekVisitView(visit: visit, area: proxy.size)
                        .id(visit.id)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(peek.visit != nil)
        .accessibilityHidden(true)
    }
}

private struct CatPeekVisitView: View {
    @Environment(AppModel.self) private var model
    let visit: CatPeek.Visit
    let area: CGSize
    @State private var out = false
    @State private var smacked = false
    @State private var line: String?
    @State private var hop = 0
    @State private var wiggle = 0

    private let size: CGFloat = 78

    var body: some View {
        let x = catX
        let y = catY
        let angle = tilt
        ZStack {
            Mascot(mood: smacked ? .annoyed : visit.mood, size: size, hop: hop)
                .rotationEffect(.degrees(angle), anchor: .center)
                .keyframeAnimator(initialValue: 0.0, trigger: wiggle) { content, value in
                    content.rotationEffect(.degrees(value))
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-9, duration: 0.08)
                        CubicKeyframe(8, duration: 0.1)
                        CubicKeyframe(-5, duration: 0.1)
                        SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                    }
                }
                .contentShape(Circle())
                .onTapGesture(perform: smack)
                .position(x: x, y: y)
            if let line, out {
                MascotBubble(text: line, pointing: bubblePointing, actionable: false)
                    .frame(maxWidth: 220)
                    .fixedSize(horizontal: false, vertical: true)
                    .position(bubblePosition(catX: x, catY: y))
                    .transition(.scale(scale: 0.5, anchor: bubbleAnchor).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .task { await run() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: smacked) { _, new in new && (model.settings.hapticsEnabled ?? true) }
    }

    /// How much of it shows past its edge: head and shoulders when in,
    /// nothing when out.
    private var push: CGFloat {
        out ? size * (visit.side == .bottom ? 0.55 : 0.62) : -size * 0.25
    }

    private var tilt: Double {
        switch visit.side {
        case .leading: return 62
        case .trailing: return -62
        case .bottom: return 0
        }
    }

    private var catX: CGFloat {
        switch visit.side {
        case .leading: return push - size / 2
        case .trailing: return area.width - push + size / 2
        case .bottom: return area.width * visit.spot
        }
    }

    private var catY: CGFloat {
        visit.side == .bottom ? area.height - push + size / 2 : area.height * visit.spot
    }

    private var bubblePointing: Edge {
        switch visit.side {
        case .leading: .leading
        case .trailing: .trailing
        case .bottom: .bottom
        }
    }

    private var bubbleAnchor: UnitPoint {
        switch visit.side {
        case .leading: .leading
        case .trailing: .trailing
        case .bottom: .bottom
        }
    }

    private func bubblePosition(catX: CGFloat, catY: CGFloat) -> CGPoint {
        switch visit.side {
        case .leading: CGPoint(x: min(area.width - 120, catX + size * 0.55 + 110), y: catY - size * 0.1)
        case .trailing: CGPoint(x: max(120, catX - size * 0.55 - 110), y: catY - size * 0.1)
        case .bottom: CGPoint(x: min(max(120, catX), area.width - 120), y: catY - size * 0.75 - 30)
        }
    }

    private func run() async {
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { out = true }
        Feel.tap(.soft, intensity: 0.6)
        try? await Task.sleep(for: .milliseconds(380))
        wiggle += 1
        withAnimation(Motion.pop) { line = visit.line }
        try? await Task.sleep(for: .seconds(visit.seconds))
        guard !smacked else { return }
        await leave(after: 0)
    }

    private func smack() {
        guard !smacked else { return }
        smacked = true
        hop += 1
        withAnimation(Motion.pop) { line = CatPeek.smackLines.randomElement() }
        Task { await leave(after: 0.9) }
    }

    private func leave(after seconds: Double) async {
        if seconds > 0 { try? await Task.sleep(for: .seconds(seconds)) }
        withAnimation(.easeOut(duration: 0.15)) { line = nil }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { out = false }
        try? await Task.sleep(for: .milliseconds(380))
        CatPeek.shared.leave(visit.id)
    }
}
