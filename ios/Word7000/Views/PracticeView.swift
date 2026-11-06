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

    /// One way to practise, as the page shows it.
    private struct Item {
        var id: String
        var icon: String
        var tint: Color
        var title: String
        var detail: String
        var locked = false
        var action: () -> Void
    }

    private var wordItems: [Item] {
        var items: [Item] = []
        if model.stats.review > 0 {
            items.append(Item(id: "practice-missed", icon: "arrow.counterclockwise", tint: Palette.miss,
                              title: L.t("錯題本", "Missed words"),
                              detail: L.t("\(model.stats.review) 個還不熟的字", "\(model.stats.review) still shaky")) {
                model.startStudySession(onlyIds: model.reviewWordIds)
                start(.study)
            })
        }
        let english = model.studyMode == .english
        items.append(Item(id: "practice-spell", icon: "pencil.line", tint: Palette.accent,
                          title: english ? L.t("拼字", "Spelling") : L.t("寫字", "Writing"),
                          detail: english ? L.t("看中文，把句子裡的字打出來", "Read the Chinese, type the missing word")
                                          : L.t("看英文，寫出中文", "Write the Chinese for the English")) {
            start(english ? .cloze : .spelling)
        })
        if english {
            items.append(Item(id: "practice-exam-style", icon: "checklist", tint: Palette.chinese,
                              title: L.t("考 10 題", "10 exam questions"),
                              detail: L.t("學測題型，學過的字", "Exam style, words you've learned")) {
                start(.quickExam)
            })
        }
        items.append(Item(id: "practice-meaning", icon: "list.bullet.rectangle", tint: Palette.known,
                          title: L.t("看字選意思", "Pick the meaning"), detail: L.t("快速四選一", "Quick multiple choice")) {
            quizSetupOpen = true
        })
        items.append(Item(id: "practice-mock", icon: "timer", tint: Palette.review,
                          title: L.t("模擬考", "Mock exam"),
                          detail: L.t("限時 \(ExamView.minutes) 分鐘", "\(ExamView.minutes) minutes, timed"),
                          locked: plus.decide(.examPractice) != .allowed) {
            start(.exam)
        })
        return items
    }

    private var speakingItems: [Item] {
        [
            Item(id: "practice-scenarios", icon: "bubble.left.and.text.bubble.right.fill", tint: TodayView.speakingTint,
                 title: L.t("情境關卡", "Scenarios"), detail: L.t("餐廳、商店、看醫生……", "A restaurant, a shop, the doctor…")) {
                model.settings.speakingWordsTab = false
                start(.speaking)
            },
            Item(id: "practice-word-speaking", icon: "mic.fill", tint: TodayView.speakingTint,
                 title: L.t("單字口說", "Speak with words"), detail: L.t("用學過的字回答問題", "Answer with words you've learned")) {
                model.settings.speakingWordsTab = true
                start(.speaking)
            },
        ]
    }

    var body: some View {
        // The one most worth doing now leads, big (the missed words when
        // there are any, else spelling); the rest are tiles two by two, so
        // the page is seen at a glance, as Duolingo's practice hub leads with
        // your mistakes.
        let words = wordItems
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let featured = words.first { featuredCard(featured) }
                header(L.t("單字", "Words")).padding(.top, 6)
                grid(Array(words.dropFirst()))
                header(L.t("口說", "Speaking")).padding(.top, 6)
                grid(speakingItems)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 110)
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

    /// The practice to do now, on the same leather or paper as Today's card.
    private func featuredCard(_ item: Item) -> some View {
        Button(action: item.action) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(TodayView.cream)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(TodayView.cream.opacity(0.16)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("現在最值得練", "Worth doing now"))
                        .font(.display(.caption, weight: .bold))
                        .foregroundStyle(TodayView.cream.opacity(0.8))
                    Text(item.title)
                        .font(.display(.title2, weight: .heavy))
                        .foregroundStyle(TodayView.cream)
                    Text(item.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TodayView.cream.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(TodayView.cream)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HeroBackground(tone: .words) }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier(item.id)
    }

    private func grid(_ items: [Item]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(items, id: \.id) { tile($0) }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.display(.title3, weight: .heavy))
            .foregroundStyle(Palette.secondaryLabel)
            .padding(.leading, 4)
    }

    /// Every row on the same plain paper, laid down a little by hand: one
    /// colour per row was too busy, and ruled or graph paper ran lines
    /// through the text.
    private static let tilts: [String: Double] = [
        "practice-missed": -0.5, "practice-spell": 0.4, "practice-exam-style": -0.3,
        "practice-meaning": 0.5, "practice-mock": -0.4, "practice-scenarios": 0.4,
        "practice-word-speaking": -0.4,
    ]

    /// A tile on the same plain paper as the rest, laid down a little by hand.
    private func tile(_ item: Item) -> some View {
        let tilt = Self.tilts[item.id] ?? 0
        return Button(action: item.action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background { RaisedFill(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: item.tint, depth: 3) }
                Spacer(minLength: 0)
                Text(item.title)
                    .font(.display(.headline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
            .background { PracticePaper(paper: .ivory) }
            .overlay(alignment: .topTrailing) {
                if item.locked { PlusBadgeFitting().padding(10) }
            }
            .rotationEffect(.degrees(tilt))
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier(item.id)
    }
}

/// A practice row's paper: cut paper, torn along the bottom, in the
/// collage; a soft leather-edged card otherwise.
private struct PracticePaper: View {
    @Environment(\.appStyle) private var appStyle
    var paper: PaperKind

    var body: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 3, seed: 5))
                .shadow(color: .black.opacity(0.07), radius: 3, y: 2)
        } else {
            PremiumSurface(radius: 20)
        }
    }
}
