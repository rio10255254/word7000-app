import SwiftUI
import Word7000Core

/// WordCat Next: every way to practise outside today's path, in one tab,
/// the way Duolingo keeps its practice hub. Two short lists, words and
/// speaking; each row is one tap into a round.
struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var start: (Activity) -> Void
    @State private var quizSetupOpen = false
    @State private var quizQueued = false
    /// The page's height, so the tiles grow into it rather than leave the
    /// bottom half empty.
    @State private var pageHeight: CGFloat = 0

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
                              detail: L.t("\(model.stats.review) 個還不熟", "\(model.stats.review) still shaky")) {
                model.startStudySession(onlyIds: model.missedRoundIds)
                start(.study)
            })
        }
        let english = model.studyMode == .english
        items.append(Item(id: "practice-spell", icon: "pencil.line", tint: Palette.accent,
                          title: english ? L.t("拼字", "Spelling") : L.t("寫字", "Writing"),
                          detail: english ? L.t("看中文拼出句中字", "Type the missing word")
                                          : L.t("看英文寫中文", "Write the Chinese")) {
            start(english ? .cloze : .spelling)
        })
        if english {
            items.append(Item(id: "practice-exam-style", icon: "checklist", tint: Palette.chinese,
                              title: L.t("考 10 題", "10 exam questions"),
                              detail: L.t("\(model.examStyleName)題型", "Exam style")) {
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
                 title: L.t("生活情境", "Scenarios"), detail: L.t("餐廳、商店、看醫生", "Restaurant, shop, doctor")) {
                model.settings.speakingWordsTab = false
                start(.speaking)
            },
            Item(id: "practice-word-speaking", icon: "mic.fill", tint: TodayView.speakingTint,
                 title: L.t("單字口說", "Word speaking"), detail: L.t("用學過的字回答", "Answer with your words")) {
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
        // Short tiles, icon beside the name, so the whole page fits one
        // screen; it still scrolls at the large text sizes.
        let tileHeight = tileHeight(wordTiles: max(0, words.count - 1))
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let featured = words.first { featuredCard(featured) }
                header(L.t("單字", "Words")).padding(.top, 8)
                grid(Array(words.dropFirst()), height: tileHeight)
                header(L.t("口說", "Speaking")).padding(.top, 8)
                grid(speakingItems, height: tileHeight)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
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

    /// What is left for the tiles once the card, the headers, the gaps and
    /// the tab bar are counted, shared by the rows: never below the short
    /// tile, never a slab. Its own function, so the body stays quick to
    /// type-check on the release Xcode.
    private func tileHeight(wordTiles: Int) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 68 }
        let rowCount: Int = (wordTiles + 1) / 2 + (speakingItems.count + 1) / 2
        let rows = CGFloat(max(1, rowCount))
        let fixed: CGFloat = 118 + 96 + 68 + 40 + (rows - 2) * 10
        let spare: CGFloat = pageHeight - fixed
        return min(150, max(68, spare / rows))
    }

    /// The practice to do now, on the same leather or paper as Today's card.
    private func featuredCard(_ item: Item) -> some View {
        Button(action: item.action) {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(TodayView.cream)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(TodayView.cream.opacity(0.16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("現在最值得練", "Worth doing now"))
                        .font(.display(.caption, weight: .bold))
                        .foregroundStyle(TodayView.cream.opacity(0.8))
                    Text(item.title)
                        .font(.display(.title2, weight: .heavy))
                        .foregroundStyle(TodayView.cream)
                    Text(item.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TodayView.cream.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(TodayView.cream)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HeroBackground(tone: .words) }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier(item.id)
    }

    private func grid(_ items: [Item], height: CGFloat) -> some View {
        // One column at the accessibility text sizes, where two cut the titles short.
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(items, id: \.id) { tile($0, height: height) }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.display(.headline, weight: .heavy))
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
    private func tile(_ item: Item, height: CGFloat) -> some View {
        let tilt = Self.tilts[item.id] ?? 0
        let tall = height >= 104
        return Button(action: item.action) {
            Group {
                if tall { tallTile(item) } else { shortTile(item) }
            }
            .padding(tall ? 14 : 12)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : height, alignment: .topLeading)
            .background(alignment: .bottomTrailing) {
                // A big faint copy of the icon in the corner, so a tall tile is not bare.
                if tall {
                    Image(systemName: item.icon)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(item.tint.opacity(0.13))
                        .rotationEffect(.degrees(-10))
                        .offset(x: 8, y: 10)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
            .background { PracticePaper(paper: .ivory) }
            .overlay(alignment: .topTrailing) {
                if item.locked { PlusBadge(compact: true).padding(6) }
            }
            .rotationEffect(.degrees(tilt))
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier(item.id)
    }
}

extension PracticeView {
    /// Icon on top, the name, and two lines on what it is.
    private func tallTile(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            icon(item, size: 46)
            Spacer(minLength: 6)
            Text(item.title)
                .font(.display(.headline, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(item.detail)
                .font(.caption)
                .foregroundStyle(Palette.secondaryLabel)
                .lineLimit(2)
        }
    }

    /// Icon beside the name, for a short screen.
    private func shortTile(_ item: Item) -> some View {
        HStack(spacing: 10) {
            icon(item, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.display(.subheadline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private func icon(_ item: Item, size: CGFloat) -> some View {
        Image(systemName: item.icon)
            .font(.system(size: size * 0.43, weight: .bold))
            .foregroundStyle(Palette.surface)
            .frame(width: size, height: size)
            .background { RaisedFill(shape: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous), tint: item.tint, depth: 3) }
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
