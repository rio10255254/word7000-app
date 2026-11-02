import SwiftUI
import Word7000Core

/// For a new learner, after their first round: the cat suggests one thing
/// they have not tried yet, in its bubble on Today, and circles the tile.
/// Using it (from the suggestion or on their own) moves to the next; one that
/// is ignored for a few days is passed over. Learners from before it was
/// added never see it.
enum GuideStep: String, CaseIterable, Sendable {
    case quiz, speaking, spelling, exam, scan, chat

    /// The Today tile to circle, when it has one.
    var tileId: String? {
        switch self {
        case .quiz: "today-quiz"
        case .speaking: "today-speaking"
        case .spelling: "today-spelling"
        case .exam: "today-exam"
        case .scan, .chat: nil
        }
    }

    /// What the cat says. Plus features are introduced as what they do, and
    /// tapping opens Plus (with the App Store's free trial) for a learner
    /// without it.
    func line(plus: Bool) -> String {
        switch self {
        case .quiz: L.t("背完了？來個小測驗，看你是真記得還是假記得。", "Done? Quick quiz: let's see if it actually stuck.")
        case .speaking: L.t("光認得不夠，開口說說看。點這裡，我聽著。", "Recognizing isn't enough. Say it out loud; tap here, I'm listening.")
        case .spelling: L.t("拼得出來才算真的會。來拼拼看？", "Spell it and you really know it. Give it a go?")
        case .exam: plus
            ? L.t("來場 15 分鐘模擬考，看看哪一級還不熟。", "Try a 15-minute mock exam and see which level still needs work.")
            : L.t("Plus 有 15 分鐘模擬考，交卷就知道哪一級還不熟。點這裡看看。", "Plus has a 15-minute mock exam that shows which level needs work. Tap to see.")
        case .scan: plus
            ? L.t("有自己的單字表？拍下來，手寫的也行，我幫你變成卡片。點這裡。", "Got your own word list? Snap it, handwriting too, and I'll make cards. Tap here.")
            : L.t("課本、講義的單字表拍一下就變成字庫，手寫也讀得懂。這是 Plus 的。點這裡看看。", "Snap a word list from a textbook or handout and it becomes a bank, handwriting too. That's Plus. Tap to see.")
        case .chat: plus
            ? L.t("哪個字搞不懂就問我：用法、例句、跟別的字差在哪。點這裡跟我聊。", "Stuck on a word? Ask me: usage, examples, how it differs. Tap here to chat.")
            : L.t("我還會講解單字、改你的口說、陪你聊天，那是 Plus 的我。點這裡認識一下。", "I can also explain words, fix your speaking and chat with you: that's the Plus me. Tap to meet it.")
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
        case .study: return nil
        }
    }

    /// Days a suggestion stays before the cat moves on.
    static let patienceDays = 3
}

/// Little things about one screen, said once by the cat the first time a new
/// learner opens it.
enum CatTip: String, CaseIterable, Sendable {
    case study, words, wordDetail, speaking, quiz, spelling, me, scan

    var text: String {
        switch self {
        case .study: L.t("點卡片看答案。認得往右滑、不熟往左滑；右上角能復原上一張，眼睛可以直接顯示答案。",
                         "Tap the card for the answer. Swipe right if you knew it, left if not; undo is top right, and the eye shows answers straight away.")
        case .words: L.t("中文、英文、例句都能搜。上面可以換字庫和篩選，長按字庫可以改名、管理單字。",
                         "Search Chinese, English or examples. Switch banks and filter up top; press and hold a bank to rename or manage it.")
        case .wordDetail: L.t("點喇叭聽發音，星星收藏。Plus 可以請我講解用法、例句和常見陷阱。",
                              "Tap the speaker to hear it, the star to save it. With Plus I explain usage, examples and common traps.")
        case .speaking: L.t("看題目開口說，說完按「我說完了」。Plus 的 AI 口說教練會幫你改句子、再追問一題。",
                            "Read the prompt and answer out loud, then tap when you're done. Plus's AI coach rewrites your answer and asks a follow-up.")
        case .quiz: L.t("選錯也沒關係，我會告訴你選到的那個是什麼意思。", "Wrong is fine: I'll tell you what the option you picked really means.")
        case .spelling: L.t("聽發音、看意思，把單字拼出來。卡住就按提示，一次多給一個字母。",
                            "Listen, read the meaning, and spell the word. Stuck? Each hint gives one more letter.")
        case .me: L.t("這裡有我估的程度、每週紀錄和設定，紙張或皮革風格也在設定裡換。",
                      "Here is the level I estimate, your week and Settings, where you can switch between paper and leather.")
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
        return GuideStep.allCases.first { step in
            guard !tried.contains(step.rawValue) else { return false }
            if step == .spelling, studyMode != .english { return false }
            if let first = offered[step.rawValue], let end = DayMath.addDays(first, GuideStep.patienceDays), today >= end { return false }
            return true
        }
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
    /// The cat's one-time tip for this screen, floating at its top or bottom.
    /// `inset` keeps it clear of a navigation bar or a row of buttons.
    func catTip(_ tip: CatTip, at edge: VerticalEdge = .bottom, inset: CGFloat = 12) -> some View {
        modifier(CatTipModifier(tip: tip, edge: edge, inset: inset))
    }
}

private struct CatTipModifier: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tip: CatTip
    let edge: VerticalEdge
    let inset: CGFloat
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: edge == .top ? .top : .bottom) {
                if shown {
                    CatTipCard(text: tip.text) {
                        withAnimation(reduceMotion ? nil : Motion.reveal) { shown = false }
                    }
                    .padding(.horizontal, 16)
                    .padding(edge == .top ? .top : .bottom, inset)
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
            }
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
