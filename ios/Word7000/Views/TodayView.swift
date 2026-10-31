import SwiftUI
import Word7000Core

/// How much room Today has on the phone it runs on, and the sizes that follow.
/// Three heights cover every iPhone: SE-sized (about 600 points between the
/// status bar and the tab bar), the usual 6.1" to 6.3" phones, and the big Plus
/// and Pro Max ones (about 750 and up).
private struct TodayMetrics {
    enum Tier { case compact, regular, tall }
    var tier: Tier
    /// Accessibility text sizes: one column, nothing peeking over the card.
    var large: Bool

    init(height: CGFloat, large: Bool) {
        self.large = large
        tier = height < 630 ? .compact : height < 750 ? .regular : .tall
    }

    var compact: Bool { tier == .compact }
    var tall: Bool { tier == .tall }
    var spacing: CGFloat { compact ? 12 : tall ? 20 : 16 }
    var ring: CGFloat { compact ? 84 : tall ? 116 : 100 }
    var heroPadding: CGFloat { compact ? 16 : tall ? 22 : 20 }
    var mascot: CGFloat { compact ? 58 : tall ? 80 : 70 }
    /// How far the companion rises above the hero card's top edge.
    var peek: CGFloat { (mascot * 0.42).rounded() }
    /// Room above the card so the companion stays clear of the header.
    var heroTop: CGFloat { large ? 0 : max(0, peek + 6 - spacing) }
    /// Practice tiles: tall cards on the big phones, short rows elsewhere.
    var tallTiles: Bool { tall && !large }
    var tileSpacing: CGFloat { compact ? 8 : tall ? 12 : 10 }
    /// The shortest and tallest a tile may be. When everything fits, the tiles
    /// grow from the shortest toward the tallest to use the room left over.
    /// The tiles' type and icon grow with the room they have, so a big tile
    /// is never a small label in a lot of empty space.
    func tileStyle(tallCard: Bool) -> PracticeTileStyle {
        if compact { return PracticeTileStyle(icon: 36, title: .subheadline, detail: .caption) }
        if tallCard { return PracticeTileStyle(icon: 54, title: .title2, detail: .subheadline) }
        return PracticeTileStyle(icon: tall ? 52 : 48, title: .title3, detail: .subheadline)
    }

    func tileHeight(tallCard: Bool) -> (min: CGFloat, max: CGFloat) {
        if tallCard { return (112, 172) }
        return compact ? (54, 92) : tall ? (70, 112) : (62, 122)
    }
}

/// One goal, one button, and the little companion cheering you on. The page
/// is fitted to the phone: when it all fits, it does not scroll and the
/// practice tiles grow into whatever room is left (tall cards on the big
/// phones, short rows on the rest); only when it does not fit, as with very
/// large text, does it scroll. The companion peeks over the hero card, always
/// clear of the buttons, and its speech bubble never takes a touch.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var studySettingsOpen = false
    /// The quiz's few settings, in a half-height sheet before it starts.
    @State private var quizSetupOpen = false
    @State private var quizQueued = false
    /// Bumped to bounce the streak flame: on arrival and when the streak grows.
    @State private var flameBounce = 0
    @State private var greetingHops = 0
    /// Taps on each practice tile, to bounce its icon.
    @State private var tileTaps: [String: Int] = [:]

    var start: (Activity) -> Void

    var body: some View {
        let progress = model.progress

        GeometryReader { proxy in
            let metrics = TodayMetrics(height: proxy.size.height, large: dynamicTypeSize.isAccessibilitySize)
            ViewThatFits(in: .vertical) {
                // It all fits: no scrolling, and the tiles take up the slack.
                page(metrics, fill: true)
                    .frame(maxHeight: .infinity, alignment: .top)
                // It doesn't (very large text, or several notices on a small phone).
                ScrollView {
                    page(metrics, fill: false)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background { AmbientBackground(tint: model.goalDone ? Palette.known : Palette.accent) }
        .animation(reduceMotion ? nil : Motion.reveal, value: plus.nudge)
        .task {
            // A little hello from the flame and the mascot each time Today comes into view.
            try? await Task.sleep(for: .milliseconds(500))
            guard !reduceMotion else { return }
            if model.progress.streak > 0 { flameBounce += 1 }
            greetingHops += 1
        }
        .onChange(of: progress.streak) { old, new in
            if new > old, !reduceMotion { flameBounce += 1 }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tileTaps) { _, _ in model.settings.hapticsEnabled ?? true }
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet().compactSheet() }
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
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.close) { quizSetupOpen = false }
                    }
                }
            }
            .compactSheet()
        }
    }

    private func page(_ m: TodayMetrics, fill: Bool) -> some View {
        VStack(alignment: .leading, spacing: m.spacing) {
            header(m)
                // Drawn above the card, so its buttons always win the tap.
                .zIndex(1)
            hero(m)
                .entrance(0, distance: 10)
            notices
            practice(m, fill: fill)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, m.compact ? 6 : 12)
        .padding(.bottom, m.compact ? 12 : 20)
    }

    // MARK: Header

    /// The greeting and date, with the language switch and the bank being
    /// studied (a chip that opens the study scope).
    private func header(_ m: TodayMetrics) -> some View {
        // At accessibility text sizes the controls drop below the greeting.
        let layout = m.large ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                             : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        return layout {
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.display(m.tall ? .title : .title2, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // Formatted in the interface language, which follows the study mode.
                HStack(spacing: 4) {
                    Image(systemName: daySymbol)
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.bounce, value: greetingHops)
                    Text(Date.now, format: .dateTime.month().day().weekday(.wide))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            if !m.large { Spacer(minLength: 4) }
            HStack(spacing: 8) {
                languageSwitch
                scopeChip
            }
            .layoutPriority(1)
        }
    }

    private var scopeChip: some View {
        Button { studySettingsOpen = true } label: {
            HStack(spacing: 6) {
                Image(systemName: model.settings.studyFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : "books.vertical.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(Palette.accent)
                Text(model.bankName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background { PremiumSurface(radius: 18) }
            .contentShape(Capsule())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(L.t("學習範圍：\(model.bankName)", "Study scope: \(model.bankName)"))
        .accessibilityIdentifier("today-study-filter")
    }

    /// Which language is being learned, switched in one tap: EN for English
    /// (with a Chinese interface), 中 for Chinese (with an English one).
    private var languageSwitch: some View {
        HStack(spacing: 2) {
            ForEach([StudyMode.english, StudyMode.chinese], id: \.self) { mode in
                let selected = model.studyMode == mode
                Button {
                    guard !selected else { return }
                    withAnimation(reduceMotion ? nil : Motion.reveal) { model.setStudyMode(mode) }
                } label: {
                    Text(mode == .english ? "EN" : "中")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                        .frame(minWidth: 34, minHeight: 30)
                        .background(selected ? Palette.accent : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(mode == .english ? L.t("學英文", "Learn English") : L.t("學中文", "Learn Chinese"))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(mode == .english ? "today-language-en" : "today-language-zh")
            }
        }
        .padding(3)
        .background { PremiumSurface(radius: 18) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.t("學習語言", "Learning language"))
        .accessibilityIdentifier("today-language")
    }

    // MARK: Hero

    private func hero(_ m: TodayMetrics) -> some View {
        let progress = model.progress
        let plan = model.studyPlan
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        let summary = VStack(alignment: .leading, spacing: m.compact ? 6 : 8) {
            Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                .font(.display(m.compact ? .title3 : .title2, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Self.cream)
                .contentTransition(.opacity)
            Text(L.todayPlan(due: plan.review, fresh: plan.fresh))
                .font(m.tall ? .subheadline : .footnote)
                .foregroundStyle(Self.cream.opacity(0.85))
            HStack(spacing: 6) {
                heroChip {
                    Label {
                        Text(L.t("\(progress.streak) 天", "\(progress.streak)d"))
                            .contentTransition(.numericText(value: Double(progress.streak)))
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.25)],
                                                            startPoint: .top, endPoint: .bottom))
                            .symbolEffect(.bounce, value: flameBounce)
                    }
                }
                .accessibilityLabel(L.t("連續 \(progress.streak) 天", "\(progress.streak)-day streak"))
                heroChip {
                    if model.goalDone {
                        Label(L.t("達成", "Done"), systemImage: "checkmark.seal.fill")
                    } else {
                        Label(L.t("差 \(left) 個", "\(left) to go"), systemImage: "target")
                            .contentTransition(.numericText(value: Double(left)))
                    }
                }
                .accessibilityLabel(model.goalDone ? L.t("目標達成", "Goal reached") : L.t("還差 \(left) 個", "\(left) to go"))
            }
        }
        let ring = ProgressRing(fraction: model.dailyFraction, color: Self.cream, lineWidth: m.compact ? 9 : m.tall ? 12 : 11, track: Self.cream.opacity(0.22)) {
            VStack(spacing: 0) {
                Text("\(progress.studiedToday)")
                    .font(.display(m.compact ? .title2 : m.tall ? .largeTitle : .title, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(progress.studiedToday)))
                Text(L.ofTarget(progress.dailyTarget))
                    .font(.display(.caption2, weight: .semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(Self.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, 12)
        }
        .frame(width: m.ring, height: m.ring)

        return VStack(alignment: .leading, spacing: m.compact ? 14 : 18) {
            if m.large {
                // With very large text the way in comes first, before it scrolls out of reach.
                summary
                startButton(m)
                ring
            } else {
                HStack(alignment: .center, spacing: m.compact ? 14 : 18) {
                    ring
                    summary
                    Spacer(minLength: 0)
                }
                startButton(m)
            }
        }
        .padding(m.heroPadding)
        .background { HeroBackground(done: model.goalDone) }
        // The companion peeks over the card's top edge, its bubble to its left.
        .overlay(alignment: .topTrailing) {
            if !m.large {
                MascotBuddy(mood: mascotMood, size: m.mascot, lines: mascotLines, greeting: mascotGreeting,
                            bubbleSide: .leading, hop: greetingHops + tileTaps.values.reduce(0, +))
                    .offset(x: -12, y: -m.peek)
                    .accessibilityIdentifier("today-mascot")
            }
        }
        .padding(.top, m.heroTop)
        .animation(reduceMotion ? nil : Motion.reveal, value: model.goalDone)
    }

    private func startButton(_ m: TodayMetrics) -> some View {
        Button {
            model.ensureStudySession()
            start(.study)
        } label: {
            HStack(spacing: 8) {
                Text(model.primaryActionTitle)
                Image(systemName: "arrow.right")
                    .symbolEffect(.bounce, value: greetingHops)
            }
            .font(.headline)
            .foregroundStyle(model.goalDone ? Self.doneDeep : Self.deep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, m.compact ? 13 : m.tall ? 17 : 15)
            .background(Self.cream, in: Capsule())
            .shadow(color: PremiumSurface.umber.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(model.studyPlan.total == 0)
        .opacity(model.studyPlan.total == 0 ? 0.55 : 1)
        .accessibilityIdentifier("today-start")
    }

    private func heroChip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.display(.footnote, weight: .semibold))
            .foregroundStyle(Self.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Self.cream.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Self.cream.opacity(0.28), lineWidth: 1))
    }

    /// The rare one-off notes: streak protection used, or a Plus reminder.
    @ViewBuilder
    private var notices: some View {
        if model.streakProtectionJustUsed {
            Label {
                Text(L.t("連勝保護幫你保住了 \(model.progress.streak) 天連勝，今天學 1 個字就能延續。",
                         "Streak protection kept your \(model.progress.streak)-day streak. One word today keeps it going."))
                    .font(.footnote)
            } icon: {
                Image(systemName: "shield.lefthalf.filled").foregroundStyle(Palette.review)
            }
            .card(padding: 12)
            .accessibilityIdentifier("today-streak-protected")
        }
        if let nudge = plus.nudge {
            PlusNudgeBanner(nudge: nudge)
                .card(padding: 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Companion

    private var mascotMood: Mascot.Mood {
        if model.goalDone { return .cheer }
        if model.progress.studiedToday > 0 { return .happy }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 23 || hour < 5 ? .sleepy : .idle
    }

    /// What it says on arrival: where today stands.
    private var mascotGreeting: String {
        let progress = model.progress
        if model.goalDone { return L.t("今天的目標完成了！", "Today's goal is done!") }
        if progress.studiedToday == 0 { return L.t("今天一起學 \(progress.dailyTarget) 個字！", "\(progress.dailyTarget) words today?") }
        return L.t("再 \(max(0, progress.dailyTarget - progress.studiedToday)) 個就達標！", "\(max(0, progress.dailyTarget - progress.studiedToday)) more to go!")
    }

    /// What it says when tapped.
    private var mascotLines: [String] {
        model.goalDone
            ? [L.t("你超棒的！", "You're amazing!"), L.t("要不要再測驗一下？", "Fancy a quick quiz?"), L.t("明天也要來喔！", "See you tomorrow!")]
            : [L.t("今天也一起加油！", "Let's do this!"), L.t("再背幾個字吧～", "A few more words?"), L.t("你做得很好喔！", "You're doing great!"),
               L.t("戳我不會變聰明喔", "Poking me won't make you smarter!"), L.t("學完記得休息一下", "Take a break after this one")]
    }

    private var daySymbol: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<17: return "sun.max.fill"
        case 17..<19: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        // Short in English too, so it fits beside the controls on a small phone.
        case 5..<12: return L.t("早安！", "Morning!")
        case 12..<18: return L.t("午安！", "Afternoon!")
        default: return L.t("晚安！", "Evening!")
        }
    }

    // MARK: Practice

    /// The words still shaky, as a full-width tile above the others.
    private var reviewTile: PracticeTileItem? {
        guard model.stats.review > 0 else { return nil }
        return PracticeTileItem(id: "today-review", icon: "arrow.counterclockwise", tint: Palette.miss,
                                title: L.practiceStruggling, detail: L.t("練到熟為止", "Until they stick"),
                                badge: "\(model.stats.review)") {
            model.startStudySession(onlyIds: model.reviewWordIds)
            start(.study)
        }
    }

    private var tiles: [PracticeTileItem] {
        var items: [PracticeTileItem] = []
        items.append(PracticeTileItem(id: "today-quiz", icon: "checklist", tint: Palette.chinese, title: L.quickQuiz,
                                      detail: L.t("\(model.settings.quizQuestionCount) 題", "\(model.settings.quizQuestionCount) questions")) { quizSetupOpen = true })
        items.append(PracticeTileItem(id: "today-speaking", icon: "bubble.left.and.text.bubble.right.fill", tint: Palette.known, title: L.speaking,
                                      detail: L.t("開口說說看", "Say it out loud")) { start(.speaking) })
        // Typing the word only makes sense when English is what is learned.
        if model.studyMode == .english {
            items.append(PracticeTileItem(id: "today-spelling", icon: "character.cursor.ibeam", tint: Palette.accent, title: L.spelling,
                                          detail: L.t("\(Spelling.sessionLength) 題", "\(Spelling.sessionLength) words")) { start(.spelling) })
        }
        items.append(PracticeTileItem(id: "today-exam", icon: "timer", tint: Palette.review, title: L.t("模擬考", "Exam"),
                                      detail: L.t("限時 \(ExamView.minutes) 分鐘", "\(ExamView.minutes) min timed"),
                                      locked: plus.decide(.examPractice) != .allowed) { start(.exam) })
        return items
    }

    private func practice(_ m: TodayMetrics, fill: Bool) -> some View {
        let items = tiles
        let columns = m.large ? 1 : 2
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return VStack(alignment: .leading, spacing: m.tileSpacing) {
            Text(L.practice)
                .font(.display(m.compact ? .headline : .title3, weight: .bold))
                .padding(.leading, 4)
            if let review = reviewTile {
                tile(review, tallCard: false, m, fill: fill, order: 1)
            }
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: m.tileSpacing) {
                    ForEach(Array(rows[row].enumerated()), id: \.element.id) { offset, item in
                        // A tile alone on its row spans it as a short row.
                        tile(item, tallCard: m.tallTiles && rows[row].count == columns, m, fill: fill,
                             order: 2 + row * columns + offset)
                    }
                }
            }
        }
    }

    private func tile(_ item: PracticeTileItem, tallCard: Bool, _ m: TodayMetrics, fill: Bool, order: Int) -> some View {
        let height = m.tileHeight(tallCard: tallCard)
        return Button {
            tileTaps[item.id, default: 0] += 1
            item.action()
        } label: {
            PracticeTile(item: item, tallCard: tallCard, style: m.tileStyle(tallCard: tallCard),
                         minHeight: height.min, maxHeight: fill ? height.max : nil,
                         bounce: tileTaps[item.id, default: 0])
        }
        .buttonStyle(TilePressStyle())
        .entrance(order, distance: 12)
        .accessibilityIdentifier(item.id)
    }

    private static let deep = Color(red: 0.45, green: 0.27, blue: 0.16)
    private static let doneDeep = Color(red: 0.3, green: 0.38, blue: 0.22)
    /// Text and the button on the leather card.
    private static let cream = Color(red: 1.0, green: 0.97, blue: 0.91)
}

/// One way to practise, as a tile.
struct PracticeTileItem: Identifiable {
    var id: String
    var icon: String
    var tint: Color
    var title: String
    var detail: String
    var locked = false
    var badge: String? = nil
    var action: () -> Void
}

/// Pressing a tile sinks it a little and tips it toward the finger's side,
/// like pressing into soft leather.
private struct TilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            .scaleEffect(pressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .rotation3DEffect(.degrees(pressed ? 4 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .animation(reduceMotion ? nil : configuration.isPressed ? Motion.press : Motion.pop, value: configuration.isPressed)
    }
}

/// A practice tile. On the big phones a tall card: the icon up top, the title
/// and detail along the bottom, and a large faint copy of the icon in the
/// corner. Elsewhere a short row: icon, title and detail side by side. Either
/// grows between its shortest and tallest to fill the page.
/// The icon and type sizes of a practice tile.
struct PracticeTileStyle {
    var icon: CGFloat
    var title: Font.TextStyle
    var detail: Font
}

private struct PracticeTile: View {
    var item: PracticeTileItem
    var tallCard = false
    var style: PracticeTileStyle
    var minHeight: CGFloat
    var maxHeight: CGFloat?
    var bounce = 0

    var body: some View {
        Group {
            if tallCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        icon(size: style.icon)
                        Spacer(minLength: 4)
                        trailing
                    }
                    Spacer(minLength: 10)
                    Text(item.title)
                        .font(.display(style.title, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(item.detail)
                        .font(style.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(14)
            } else {
                HStack(spacing: style.icon > 40 ? 14 : 10) {
                    icon(size: style.icon)
                    VStack(alignment: .leading, spacing: 2) {
                        // Two lines when a long title ("Speaking practice") meets a narrow tile.
                        Text(item.title)
                            .font(.display(style.title, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        Text(item.detail)
                            .font(style.detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 2)
                    trailing
                }
                .padding(.horizontal, style.icon > 40 ? 14 : 12)
                .padding(.vertical, style.icon > 40 ? 10 : 8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight, alignment: tallCard ? .topLeading : .leading)
        .background {
            PremiumSurface(radius: tallCard ? 22 : 18)
                .overlay(alignment: .bottomTrailing) {
                    if tallCard {
                        // A large, faint copy of the icon tucked into the corner.
                        Image(systemName: item.icon)
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(item.tint.opacity(0.08))
                            .rotationEffect(.degrees(-12))
                            .offset(x: 10, y: 12)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: tallCard ? 22 : 18, style: .continuous))
        }
        .overlay {
            // A soft ring of the tile's colour spreads from the icon when it is tapped.
            if bounce > 0 {
                TileRipple(color: item.tint, tallCard: tallCard, iconSize: style.icon)
                    .id(bounce)
                    .clipShape(RoundedRectangle(cornerRadius: tallCard ? 22 : 18, style: .continuous))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: tallCard ? 22 : 18, style: .continuous))
    }

    private func icon(size: CGFloat) -> some View {
        Image(systemName: item.icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .symbolEffect(.bounce, value: bounce)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [item.tint.opacity(0.7), item.tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            }
            .shadow(color: item.tint.opacity(0.3), radius: 5, y: 2)
    }

    @ViewBuilder
    private var trailing: some View {
        if item.locked {
            PlusBadge()
        } else if let badge = item.badge {
            Text(badge)
                .font(.display(.caption, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(item.tint, in: Capsule())
        }
    }
}

/// One ripple from a tile's icon: a ring of its colour growing and fading.
private struct TileRipple: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var color: Color
    var tallCard: Bool
    var iconSize: CGFloat
    @State private var spread = false

    var body: some View {
        GeometryReader { proxy in
            let origin = tallCard ? CGPoint(x: 14 + iconSize / 2, y: 14 + iconSize / 2)
                                  : CGPoint(x: 14 + iconSize / 2, y: proxy.size.height / 2)
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.28), color.opacity(0)], center: .center, startRadius: 0, endRadius: iconSize / 2))
                .overlay(Circle().strokeBorder(color.opacity(0.35), lineWidth: 1.5))
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(spread ? proxy.size.width * 2.2 / iconSize : 1)
                .opacity(spread ? 0 : 1)
                .position(origin)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.55)) { spread = true }
        }
    }
}

/// The hero card's face: caramel leather darkening to brown, with a fine
/// grain, light pooling in one corner, a glint that sweeps across now and
/// then, and a hairline catching the light. It turns olive once today's goal
/// is met.
private struct HeroBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var done: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let colors = done
            ? [Color(red: 0.6, green: 0.65, blue: 0.4), Color(red: 0.33, green: 0.42, blue: 0.25)]
            : [Color(red: 0.77, green: 0.55, blue: 0.36), Color(red: 0.45, green: 0.29, blue: 0.19)]
        shape
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .topLeading) {
                        Circle()
                            .fill(Color(red: 1, green: 0.9, blue: 0.75).opacity(0.35))
                            .frame(width: width * 0.8, height: width * 0.8)
                            .blur(radius: 40)
                            .offset(x: width * 0.45, y: -width * 0.45)
                        Circle()
                            .fill(colors[1].opacity(0.7))
                            .frame(width: width * 0.7, height: width * 0.7)
                            .blur(radius: 50)
                            .offset(x: -width * 0.3, y: proxy.size.height * 0.45)
                    }
                }
                .clipShape(shape)
            }
            .overlay { PaperGrain(opacity: 1).blendMode(.overlay).clipShape(shape) }
            .overlay {
                if !reduceMotion { HeroGlint().clipShape(shape) }
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                                   lineWidth: 1)
            }
            .shadow(color: colors[1].opacity(0.35), radius: 20, y: 12)
    }
}

/// A soft band of light that crosses the hero card every few seconds.
private struct HeroGlint: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.35, height: height * 2)
                .rotationEffect(.degrees(18))
                .phaseAnimator([false, true]) { content, across in
                    content.offset(x: across ? width * 1.3 : -width * 0.6, y: -height * 0.5)
                } animation: { across in
                    across ? Animation.easeInOut(duration: 1.4).delay(4) : Animation.linear(duration: 0.01)
                }
        }
        .allowsHitTesting(false)
    }
}
