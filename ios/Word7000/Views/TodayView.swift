import SwiftUI
import Word7000Core

/// One goal, one button, and the little companion cheering you on. The page
/// is laid out to fit the screen without scrolling on every iPhone: a short
/// greeting with the study scope, the hero card with today's progress and the
/// way in, and the practice tiles. Sizes tighten on shorter phones; only very
/// large text makes it scroll.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var studySettingsOpen = false
    /// Bumped to bounce the streak flame: on arrival and when the streak grows.
    @State private var flameBounce = 0
    /// Taps on the mascot; each one makes it hop and say something.
    @State private var pokes = 0
    @State private var greetingHops = 0
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?

    var start: (Activity) -> Void

    var body: some View {
        let progress = model.progress

        GeometryReader { proxy in
            // iPhone SE, mini and the like: tighter spacing and smaller pieces.
            let compact = proxy.size.height < 700
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 12 : 16) {
                    header
                    hero(compact: compact)
                        .entrance(0, distance: 10)
                    notices
                    Spacer(minLength: 0)
                    practice(compact: compact)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, compact ? 6 : 12)
                .padding(.bottom, compact ? 12 : 20)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { AmbientBackground(tint: model.goalDone ? Palette.known : Palette.accent) }
        .toolbar(.hidden, for: .navigationBar)
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
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: pokes) { _, _ in model.settings.hapticsEnabled ?? true }
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet() }
    }

    // MARK: Header

    /// The greeting and date, with the bank being studied as a chip that opens
    /// the study scope (it replaces the toolbar filter and the footer line).
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.display(.title2, weight: .bold))
                // Formatted in the interface language, which follows the study mode.
                Text(Date.now, format: .dateTime.month().day().weekday(.wide))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button { studySettingsOpen = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: model.settings.studyFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : "books.vertical.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(Palette.accent)
                    Text(model.bankName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background { PremiumSurface(radius: 18) }
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(L.t("學習範圍：\(model.bankName)", "Study scope: \(model.bankName)"))
            .accessibilityIdentifier("today-study-filter")
        }
    }

    // MARK: Hero

    private func hero(compact: Bool) -> some View {
        let progress = model.progress
        let plan = model.studyPlan
        let large = dynamicTypeSize.isAccessibilitySize
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        let ringSize: CGFloat = compact ? 84 : 100
        let summary = VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                .font(.display(compact ? .title3 : .title2, weight: .bold))
                .foregroundStyle(Self.cream)
                .contentTransition(.opacity)
            Text(L.todayPlan(due: plan.review, fresh: plan.fresh))
                .font(.footnote)
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
        let ring = ProgressRing(fraction: model.dailyFraction, color: Self.cream, lineWidth: compact ? 9 : 11, track: Self.cream.opacity(0.22)) {
            VStack(spacing: 0) {
                Text("\(progress.studiedToday)")
                    .font(.display(compact ? .title2 : .title, weight: .bold))
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
        .frame(width: ringSize, height: ringSize)

        return VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            if large {
                // With very large text the way in comes first, before it scrolls out of reach.
                summary
                startButton(compact: compact)
                ring
            } else {
                HStack(alignment: .center, spacing: compact ? 14 : 18) {
                    ring
                    summary
                    Spacer(minLength: 0)
                }
                startButton(compact: compact)
            }
        }
        .padding(compact ? 16 : 20)
        .background { HeroBackground(done: model.goalDone) }
        // The companion peeks over the card's top edge.
        .overlay(alignment: .topTrailing) {
            if !large { mascot(size: compact ? 62 : 76).offset(x: -10, y: compact ? -26 : -32) }
        }
        .padding(.top, large ? 0 : (compact ? 18 : 24))
        .animation(reduceMotion ? nil : Motion.reveal, value: model.goalDone)
    }

    private func startButton(compact: Bool) -> some View {
        Button {
            model.ensureStudySession()
            start(.study)
        } label: {
            HStack(spacing: 8) {
                Text(model.primaryActionTitle)
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .foregroundStyle(model.goalDone ? Self.doneDeep : Self.deep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 13 : 15)
            .background(Self.cream, in: Capsule())
            .shadow(color: PremiumSurface.umber.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(model.studyPlan.total == 0)
        .opacity(model.studyPlan.total == 0 ? 0.55 : 1)
        .accessibilityIdentifier("today-start")
    }

    private func mascot(size: CGFloat) -> some View {
        Mascot(mood: mascotMood, size: size, hop: pokes + greetingHops)
            .overlay(alignment: .topTrailing) {
                if let bubble {
                    MascotBubble(text: bubble)
                        .frame(width: 170, alignment: .trailing)
                        .offset(y: -size * 0.55)
                        .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { poke() }
    }

    private func heroChip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.display(.footnote, weight: .semibold))
            .foregroundStyle(Self.cream)
            .lineLimit(1)
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

    private var mascotMood: Mascot.Mood {
        if model.goalDone { return .cheer }
        if model.progress.studiedToday > 0 { return .happy }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 23 || hour < 5 ? .sleepy : .idle
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return L.t("早安！", "Good morning!")
        case 12..<18: return L.t("午安！", "Good afternoon!")
        default: return L.t("晚安！", "Good evening!")
        }
    }

    /// A tap on the mascot: it hops, and says one of a few lines for a moment.
    private func poke() {
        pokes += 1
        let lines = model.goalDone
            ? [L.t("今天的目標完成了！", "Goal done for today!"), L.t("你超棒的！", "You're amazing!"), L.t("要不要再測驗一下？", "Fancy a quick quiz?")]
            : [L.t("今天也一起加油！", "Let's do this!"), L.t("再背幾個字吧～", "A few more words?"), L.t("你做得很好喔！", "You're doing great!"),
               L.t("戳我不會變聰明喔", "Poking me won't make you smarter!"), L.t("學完記得休息一下", "Take a break after this one")]
        var next = lines.randomElement() ?? lines[0]
        if next == bubble, let other = lines.first(where: { $0 != bubble }) { next = other }
        withAnimation(reduceMotion ? nil : Motion.pop) { bubble = next }
        bubbleTask?.cancel()
        bubbleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : Motion.reveal) { bubble = nil }
        }
    }

    // MARK: Practice

    private var tiles: [PracticeTileItem] {
        var items: [PracticeTileItem] = []
        if model.stats.review > 0 {
            items.append(PracticeTileItem(id: "today-review", icon: "arrow.counterclockwise", tint: Palette.miss,
                                          title: L.t("不熟的字", "Shaky words"), detail: L.t("練到熟為止", "Make them stick"),
                                          badge: "\(model.stats.review)") {
                model.startStudySession(onlyIds: model.reviewWordIds)
                start(.study)
            })
        }
        items.append(PracticeTileItem(id: "today-quiz", icon: "checklist", tint: Palette.chinese, title: L.quickQuiz,
                                      detail: L.t("\(model.settings.quizQuestionCount) 題", "\(model.settings.quizQuestionCount) questions")) { start(.quiz) })
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

    private func practice(compact: Bool) -> some View {
        let items = tiles
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Text(L.practice)
                .font(.display(.headline, weight: .bold))
                .padding(.leading, 4)
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: compact ? 8 : 10) {
                    ForEach(Array(rows[row].enumerated()), id: \.element.id) { offset, item in
                        tile(item, compact: compact, order: 1 + row * columns + offset)
                    }
                    if rows[row].count < columns {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func tile(_ item: PracticeTileItem, compact: Bool, order: Int) -> some View {
        Button(action: item.action) {
            PracticeTile(item: item, compact: compact)
        }
        .buttonStyle(SoftPressStyle())
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

/// A practice tile: the coloured icon, title and detail side by side, so
/// two fit across and the whole set stays short.
private struct PracticeTile: View {
    var item: PracticeTileItem
    var compact = false

    var body: some View {
        let iconSize: CGFloat = compact ? 34 : 40
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: compact ? 15 : 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(LinearGradient(colors: [item.tint.opacity(0.7), item.tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: iconSize * 0.3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: iconSize * 0.3, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                }
                .shadow(color: item.tint.opacity(0.3), radius: 5, y: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.display(.subheadline, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 2)
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
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 10 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { PremiumSurface(radius: 18) }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
