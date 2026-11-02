import SwiftUI
import Word7000Core

/// For a new learner, after their first round: the cat suggests one thing
/// they have not tried yet, in its bubble on Today, and circles the tile.
/// Using it (from the suggestion or on their own) moves to the next; one that
/// is ignored for a few days is passed over. Learners from before it was
/// added never see it.
enum GuideStep: String, CaseIterable, Sendable {
    case quiz, speaking, scan, chat, spelling

    /// The Today tile to circle, when it has one.
    var tileId: String? {
        switch self {
        case .quiz: "today-quiz"
        case .speaking: "today-speaking"
        case .spelling: "today-spelling"
        case .scan, .chat: nil
        }
    }

    var line: String {
        switch self {
        case .quiz: L.t("背完了？來個小測驗，看你是真記得還是假記得。", "Done? Quick quiz: let's see if it actually stuck.")
        case .speaking: L.t("光認得不夠，開口說說看。點這裡，我聽著。", "Recognizing isn't enough. Say it out loud; tap here, I'm listening.")
        case .scan: L.t("有自己的單字表？拍下來，我幫你變成卡片。點這裡。", "Got your own word list? Snap it and I'll make cards. Tap here.")
        case .chat: L.t("哪個字搞不懂就問我。點這裡跟我聊。", "Stuck on a word? Ask me. Tap here to chat.")
        case .spelling: L.t("拼得出來才算真的會。來拼拼看？", "Spell it and you really know it. Give it a go?")
        }
    }

    /// The activity that counts as having tried it.
    init?(activity: Activity) {
        switch activity {
        case .quiz, .quizReady: self = .quiz
        case .speaking: self = .speaking
        case .spelling: self = .spelling
        case .scan: self = .scan
        case .study, .exam: return nil
        }
    }

    /// Days a suggestion stays before the cat moves on.
    static let patienceDays = 3
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
            if step == .chat, !CloudAssistant.shared.offered { return false }
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
