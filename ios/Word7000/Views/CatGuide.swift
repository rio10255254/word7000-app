import SwiftUI
import Word7000Core

/// For a new learner, after their first round: the cat suggests one thing
/// they have not tried yet, in its bubble on Today, and circles the tile.
/// Using it (from the suggestion or on their own) moves to the next; one that
/// is ignored for a few days is passed over. Learners from before it was
/// added never see it.
enum GuideStep: String, CaseIterable, Sendable {
    case quiz, speaking, spelling, exam, scan, chat

    /// WordCat Next: spelling and the quizzes are steps of today's words, so
    /// the cat introduces only what lives outside them.
    static let guided: [GuideStep] = [.speaking, .scan, .chat]

    /// The control on Today to circle.
    var tileId: String? {
        switch self {
        case .quiz: "today-quiz"
        case .speaking: "today-speaking"
        case .spelling: "today-spelling"
        case .exam: nil
        case .scan: "today-scan"
        case .chat: "today-chat"
        }
    }

    /// What the cat says. Plus features are introduced as what they do, and
    /// tapping opens Plus (with the App Store's free trial) for a learner
    /// without it.
    func line(plus: Bool) -> String {
        switch self {
        case .quiz: L.t("背完了？來個小測驗，看你是真記得還是假記得。", "Done? Quick quiz: let's see if it actually stuck.")
        case .speaking: L.t("光認得不夠，開口說說看。點這裡，我聽著。", "Recognizing isn't enough. Say it out loud; tap here, I'm listening.")
        case .spelling: L.t("拼得出來才算真的會。來拼拼看？", "Write it in Chinese and you really know it. Characters or pinyin, give it a go?")
        case .exam: plus
            ? L.t("來場 15 分鐘模擬考，看看哪一章還不熟。", "Try a 15-minute mock exam and see which chapters need work.")
            : L.t("Premium 有 15 分鐘模擬考，交卷就知道哪一章還不熟。", "Premium has a 15-minute mock exam that shows which chapters need work.")
        case .scan: plus
            ? L.t("有自己的單字表？拍下來，我幫你變成卡片。", "Got your own word list? Snap it and I'll make cards.")
            : L.t("單字表拍一下就變字庫，手寫也行（Premium）。", "Snap a word list and it becomes a bank, handwriting too (Premium).")
        case .chat: plus
            ? L.t("哪個字搞不懂？點我問就好。", "Stuck on a word? Tap me and ask.")
            : L.t("我還會講解單字、改口說，那是 Premium 的我。點我看看。", "I can also explain words and fix your speaking: that's the Premium me. Tap to see.")
        }
    }

    /// The activity that counts as having tried it.
    init?(activity: Activity) {
        switch activity {
        case .quiz, .quizReady: self = .quiz
        case .speaking: self = .speaking
        case .spelling: self = .spelling
        case .scan: self = .scan
        case .exam: self = .exam
        case .study, .cloze, .quickExam, .weeklyExam: return nil
        }
    }

    /// Days a suggestion stays before the cat moves on.
    static let patienceDays = 3

    var title: String {
        switch self {
        case .quiz: L.t("看字選意思", "Pick the meaning")
        case .speaking: L.t("開口說", "Speak")
        case .spelling: L.t("拼字", "Write")
        case .exam: L.t("模擬考", "Mock exam")
        case .scan: L.t("掃描", "Scan")
        case .chat: L.t("問傻貓", "Ask the cat")
        }
    }

    var icon: String {
        switch self {
        case .quiz: "checklist"
        case .speaking: "mic.fill"
        case .spelling: "character.cursor.ibeam"
        case .exam: "timer"
        case .scan: "doc.text.viewfinder"
        case .chat: "bubble.left.and.bubble.right.fill"
        }
    }
}

/// One stop on the new learner's checklist: the first round, then each step.
struct GuideStop: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let done: Bool
    /// nil for the first round.
    let step: GuideStep?
}

/// Little things about one screen, said once by the cat the first time a new
/// learner opens it.
enum CatTip: String, CaseIterable, Sendable {
    case study, words, wordDetail, speaking, quiz, spelling, me, scan

    var text: String {
        switch self {
        case .study: L.t("點卡片看答案；認得往右滑，不熟往左滑。",
                         "Tap for the answer. Swipe right if you knew it, left if not.")
        case .words: L.t("中文、英文、例句都能搜；長按字庫可以管理。",
                         "Search Chinese, English or examples. Hold a bank to manage it.")
        case .wordDetail: L.t("點喇叭聽發音，點星星收藏。",
                              "Tap the speaker to hear it, the star to save it.")
        case .speaking: L.t("按麥克風開口說，說完會自動停。",
                            "Tap the mic and speak; it stops when you're done.")
        case .quiz: L.t("選錯沒關係，我會說你選的那個是什麼意思。", "Wrong is fine: I'll say what the one you picked means.")
        case .spelling: L.t("把單字拼出來；卡住就按提示，一次多給一個字母。",
                            "Write the Chinese for the word; each hint shows one more syllable.")
        case .me: L.t("我估的程度、每週紀錄和設定都在這裡。",
                      "Your level, your weeks and Settings are here.")
        case .scan: L.t("拍單字表，或在筆記本上一行寫一個字，只寫英文或中文我都會幫你補。",
                        "Snap a word list, or write one word a line on the notepad: English or Chinese alone, and I'll fill in the rest.")
        }
    }
}

extension AppModel {
    /// The one thing to suggest now, if any.
    var guideStep: GuideStep? {
        guard settings.guideActive == true, progress.lastStudyDate != nil, !AppRuntime.catShowcase else { return nil }
        let tried = Set(settings.guideTried ?? [])
        let offered = settings.guideOffered ?? [:]
        return GuideStep.guided.first { step in
            guard !tried.contains(step.rawValue) else { return false }
            if let first = offered[step.rawValue], let end = DayMath.addDays(first, GuideStep.patienceDays), today >= end { return false }
            return true
        }
    }

    /// The new learner's checklist on Today: the first round, then everything
    /// the cat introduces, ticked off as they are tried. Hidden once all are
    /// done or the learner closes it.
    var guideStops: [GuideStop]? {
        let testing = ProcessInfo.processInfo.arguments.contains("-uiTestingChecklist")
        guard settings.guideActive == true, settings.guideHidden != true, !AppRuntime.catShowcase,
              !AppRuntime.uiTesting || testing else { return nil }
        let tried = Set(settings.guideTried ?? [])
        var stops = [GuideStop(id: "study", title: L.t("背一組", "Learn a set"), icon: "rectangle.on.rectangle.angled",
                               done: progress.lastStudyDate != nil, step: nil)]
        for step in GuideStep.guided {
            stops.append(GuideStop(id: step.rawValue, title: step.title, icon: step.icon, done: tried.contains(step.rawValue), step: step))
        }
        return stops.allSatisfy(\.done) ? nil : stops
    }

    func hideGuideChecklist() {
        settings.guideHidden = true
        scheduleSave()
    }

    /// Notes the day a suggestion was first shown, so it can give way later.
    func noteGuideShown(_ step: GuideStep) {
        guard settings.guideOffered?[step.rawValue] == nil else { return }
        var offered = settings.guideOffered ?? [:]
        offered[step.rawValue] = today
        settings.guideOffered = offered
        scheduleSave()
    }

    /// A screen's tip is due: for a new learner, the first time only.
    func tipDue(_ tip: CatTip) -> Bool {
        if AppRuntime.uiTesting, !ProcessInfo.processInfo.arguments.contains("-uiTestingTips") { return false }
        guard settings.guideActive == true || ProcessInfo.processInfo.arguments.contains("-uiTestingTips") else { return false }
        return !(settings.seenTips ?? []).contains(tip.rawValue)
    }

    func noteTipSeen(_ tip: CatTip) {
        guard !(settings.seenTips ?? []).contains(tip.rawValue) else { return }
        settings.seenTips = (settings.seenTips ?? []) + [tip.rawValue]
        scheduleSave()
    }

    func noteTried(_ step: GuideStep) {
        guard settings.guideActive == true, !(settings.guideTried ?? []).contains(step.rawValue) else { return }
        settings.guideTried = (settings.guideTried ?? []) + [step.rawValue]
        scheduleSave()
    }
}

/// A loose ring drawn round a tile the cat is pointing at: charcoal in the
/// collage, the accent colour otherwise, drawn on once and then breathing
/// gently. It takes no touches.
struct GuideRing: View {
    @Environment(\.appStyle) private var appStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var breathe = false

    var body: some View {
        let color = appStyle == .collage ? Collage.ink.opacity(0.75) : Palette.accent
        ZStack {
            HandLoop()
                .trim(from: 0, to: reduceMotion ? 1 : drawn)
                .stroke(color, style: StrokeStyle(lineWidth: appStyle == .collage ? 2.2 : 2.6, lineCap: .round, lineJoin: .round))
                .padding(-7)
                .scaleEffect(breathe ? 1.015 : 1)
            Text(L.t("試試這個", "Try this"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Palette.accent, in: Capsule())
                .rotationEffect(.degrees(-6))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -6, y: -14)
                .opacity(reduceMotion || drawn >= 1 ? 1 : 0)
            Image(systemName: "hand.point.up.left.fill")
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .rotationEffect(.degrees(-20))
                .offset(x: breathe ? 4 : 0, y: breathe ? 4 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 6, y: 10)
                .opacity(reduceMotion || drawn >= 1 ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).delay(0.4)) { drawn = 1 }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(1.4)) { breathe = true }
        }
    }
}

/// A hand-drawn loop: a rounded rectangle that overshoots where it closes.
private struct HandLoop: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) * 0.28
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r * 1.4, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY - 1))
        path.addQuadCurve(to: CGPoint(x: rect.maxX + 1, y: rect.minY + r), control: CGPoint(x: rect.maxX + 2, y: rect.minY - 2))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY + 1), control: CGPoint(x: rect.maxX, y: rect.maxY + 2))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX - 1, y: rect.maxY - r), control: CGPoint(x: rect.minX - 2, y: rect.maxY + 1))
        path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY - 2), control: CGPoint(x: rect.minX - 1, y: rect.minY - 3))
        // Overshoot past the start, as a pen does.
        path.addLine(to: CGPoint(x: rect.minX + r * 2.2, y: rect.minY + 3))
        return path
    }
}

extension View {
    /// The cat's one-time tip for a screen, at its top or bottom edge. It
    /// takes its own room (the screen moves aside, nothing is covered), and
    /// goes away by itself after a few seconds or at a tap.
    func catTip(_ tip: CatTip, at edge: VerticalEdge = .bottom) -> some View {
        modifier(CatTipModifier(tip: tip, edge: edge))
    }
}

private struct CatTipModifier: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    let tip: CatTip
    let edge: VerticalEdge
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: edge == .top ? .top : .bottom, spacing: 0) {
                if shown {
                    CatTipCard(text: tip.text) { hide() }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture { hide() }
                        .transition(.move(edge: edge == .top ? .top : .bottom).combined(with: .opacity))
                        .accessibilityIdentifier("cat-tip-\(tip.rawValue)")
                }
            }
            .task {
                guard model.tipDue(tip) else { return }
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                // Seen once shown: it never comes back, even if left open.
                model.noteTipSeen(tip)
                withAnimation(reduceMotion ? nil : Motion.pop) { shown = true }
                // Long enough to read twice; VoiceOver users close it themselves.
                guard !voiceOver else { return }
                try? await Task.sleep(for: .seconds(8))
                hide()
            }
    }

    private func hide() {
        guard shown else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { shown = false }
    }
}

/// The cat with a short note on a scrap of paper, and a close button.
private struct CatTipCard: View {
    @Environment(\.appStyle) private var appStyle
    var text: String
    var close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Mascot(mood: .smug, size: 38)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Palette.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.close)
            .accessibilityIdentifier("cat-tip-close")
        }
        .padding(12)
        .background { surface }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: .peach)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 3, seed: 9))
                .overlay(alignment: .top) { TapeStrip(width: 48, angle: -4).offset(y: -10) }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}
