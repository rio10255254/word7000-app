import SwiftUI
import Word7000Core

/// WordCat Next: every way to practise outside today's path, in one tab,
/// the way Duolingo keeps its practice hub. Two short lists, words and
/// speaking; each row is one tap into a round.
struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    var start: (Activity) -> Void
    @State private var quizSetupOpen = false
    @State private var quizQueued = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header(L.t("單字", "Words"))
                if model.stats.review > 0 {
                    row("practice-missed", icon: "arrow.counterclockwise", tint: Palette.miss,
                        title: L.t("錯題本", "Missed words"), detail: L.t("\(model.stats.review) 個還不熟的字", "\(model.stats.review) still shaky")) {
                        model.startStudySession(onlyIds: model.reviewWordIds)
                        start(.study)
                    }
                }
                row("practice-spell", icon: "pencil.line", tint: Palette.accent,
                    title: model.studyMode == .english ? L.t("拼字", "Spelling") : L.t("寫字", "Writing"),
                    detail: model.studyMode == .english ? L.t("看中文，把句子裡的字打出來", "Read the Chinese, type the missing word")
                                                        : L.t("看英文，寫出中文", "Write the Chinese for the English")) {
                    start(model.studyMode == .english ? .cloze : .spelling)
                }
                if model.studyMode == .english {
                    row("practice-exam-style", icon: "checklist", tint: Palette.chinese,
                        title: L.t("考 10 題", "10 exam questions"), detail: L.t("學測題型，學過的字", "Exam style, on words you've learned")) {
                        start(.quickExam)
                    }
                }
                row("practice-meaning", icon: "list.bullet.rectangle", tint: Palette.known,
                    title: L.t("看字選意思", "Pick the meaning"), detail: L.t("快速四選一", "Quick multiple choice")) {
                    quizSetupOpen = true
                }
                row("practice-mock", icon: "timer", tint: Palette.review,
                    title: L.t("模擬考", "Mock exam"), detail: L.t("限時 \(ExamView.minutes) 分鐘", "\(ExamView.minutes) minutes, timed"),
                    locked: plus.decide(.examPractice) != .allowed) {
                    start(.exam)
                }

                header(L.t("口說", "Speaking")).padding(.top, 12)
                row("practice-scenarios", icon: "bubble.left.and.text.bubble.right.fill", tint: TodayView.speakingTint,
                    title: L.t("情境關卡", "Scenarios"), detail: L.t("餐廳、商店、看醫生……", "A restaurant, a shop, the doctor…")) {
                    model.settings.speakingWordsTab = false
                    start(.speaking)
                }
                row("practice-word-speaking", icon: "mic.fill", tint: TodayView.speakingTint,
                    title: L.t("單字口說", "Speak with words"), detail: L.t("用學過的字回答問題", "Answer using words you've learned")) {
                    model.settings.speakingWordsTab = true
                    start(.speaking)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 12)
        }
        .background { AmbientBackground() }
        .navigationTitle(L.t("練習", "Practice"))
        .sheet(isPresented: $quizSetupOpen, onDismiss: {
            guard quizQueued else { return }
            quizQueued = false
            start(.quizReady)
        }) {
            NavigationStack {
                QuizConfiguration(start: {
                    quizQueued = true
                    quizSetupOpen = false
                })
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L.close) { quizSetupOpen = false } }
                }
            }
            .compactSheet()
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.display(.title3, weight: .heavy))
            .foregroundStyle(Palette.secondaryLabel)
            .padding(.leading, 4)
    }

    private func row(_ id: String, icon: String, tint: Color, title: String, detail: String, locked: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background { RaisedFill(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: tint, depth: 4) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.display(.title3, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                if locked {
                    PlusBadgeFitting()
                } else {
                    Image(systemName: "chevron.right").font(.headline).foregroundStyle(Palette.tertiaryLabel)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background { HomeSurface(radius: 20) }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier(id)
    }
}
