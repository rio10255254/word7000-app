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
            // Fill-the-gap needs example sentences; a scanned or own list
            // without them is spelled from its meanings instead.
            start(english && model.clozeAvailable ? .cloze : .spelling)
        })
        // Both languages: a learner of Chinese is asked in the Chinese sentence.
        items.append(Item(id: "practice-exam-style", icon: "checklist", tint: Palette.chinese,
                          title: L.t("考 10 題", "10 exam questions"),
                          detail: model.examStyleName) {
            start(.quickExam)
        })
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
        // The tiles under the lead card come in pairs: an odd one out left a
        // hole in the grid. The pair is made up with another set of cards.
        if (items.count - 1) % 2 == 1 {
            items.append(Item(id: "practice-cards", icon: "rectangle.on.rectangle.angled", tint: Palette.accent,
                              title: L.t("翻卡", "Flip cards"), detail: L.t("再背一組", "One more set")) {
                model.startStudySession()
                start(.study)
            })
        }
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
        // The tiles grow to fill whatever phone it is, so a tall screen has
        // no empty bottom half; where even the short tiles do not fit (a
        // small phone, the large text sizes), the page scrolls instead.
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { page(words, rowHeight: nil) }
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let featured = words.first { featuredCard(featured) }
                    // Every row of tiles gets the same share of what is left,
                    // so all of them look alike and the page is filled.
                    GeometryReader { proxy in
                        let rows = rowCount(words)
                        let height = rowHeight(available: proxy.size.height, rows: rows)
                        if height >= Self.shortTile {
                            tiles(words, rowHeight: height)
                        } else {
                            ScrollView { tiles(words, rowHeight: Self.shortTile).padding(.bottom, Self.tabBarRoom) }
                                .scrollBounceBehavior(.basedOnSize)
                        }
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
            }
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

    /// The whole page in one scroll, for the accessibility text sizes: the
    /// tiles as tall as their words.
    private func page(_ words: [Item], rowHeight: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let featured = words.first { featuredCard(featured) }
            tiles(words, rowHeight: rowHeight)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, Self.tabBarRoom)
    }

    /// The words tiles and the speaking tiles under their headers, every row
    /// `rowHeight` tall (nil: as tall as it needs).
    private func tiles(_ words: [Item], rowHeight: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header(L.t("單字", "Words")).padding(.top, 8)
            grid(Array(words.dropFirst()), rowHeight: rowHeight)
            header(L.t("口說", "Speaking")).padding(.top, 8)
            grid(speakingItems, rowHeight: rowHeight)
        }
    }

    private func rowCount(_ words: [Item]) -> Int {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return (words.count - 1 + columns - 1) / columns + (speakingItems.count + columns - 1) / columns
    }

    /// The height left under the card, less the two headers, the gaps and
    /// the tab bar, shared by the rows; never taller than a comfortable tile.
    private func rowHeight(available: CGFloat, rows: Int) -> CGFloat {
        let headers: CGFloat = 2 * 32
        let gaps = CGFloat(rows + 1) * 10
        let spare = available - Self.tabBarRoom - headers - gaps
        return min(Self.tallestTile, floor(spare / CGFloat(max(1, rows))))
    }

    private static let shortTile: CGFloat = 68
    private static let tallestTile: CGFloat = 170
    /// A little air above the tab bar (the page's safe area already ends at
    /// it: the 100 points kept here before left a strip of empty paper).
    private static let tabBarRoom: CGFloat = 14
    /// From this height a tile shows its icon above the name.
    private static let tallFrom: CGFloat = 112

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

    private func grid(_ items: [Item], rowHeight: CGFloat?) -> some View {
        // One column at the accessibility text sizes, where two cut the titles short.
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows: [[Item]] = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min(items.count, $0 + columns)]) }
        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.id) { tile($0, tall: (rowHeight ?? 0) >= Self.tallFrom) }
                    if row.count < columns { Color.clear.frame(maxWidth: .infinity) }
                }
                .frame(minHeight: Self.shortTile)
                .frame(height: rowHeight)
            }
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
        "practice-word-speaking": -0.4, "practice-cards": 0.3,
    ]

    /// A tile on the same plain paper as the rest, laid down a little by hand.
    private func tile(_ item: Item, tall: Bool) -> some View {
        let tilt = Self.tilts[item.id] ?? 0
        return Button(action: item.action) {
            // Every tile on the page has the same face: icon above the name
            // when the rows are tall, beside it when they are short.
            Group {
                if tall { tallTile(item).padding(14) } else { shortTile(item).padding(12) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .topTrailing) {
                // A big faint copy of the icon in the empty top corner of a
                // tall tile, clear of the words at its foot.
                if tall {
                    Image(systemName: item.icon)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(item.tint.opacity(0.1))
                        .rotationEffect(.degrees(-10))
                        .offset(x: 6, y: -4)
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
            Spacer(minLength: 10)
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
