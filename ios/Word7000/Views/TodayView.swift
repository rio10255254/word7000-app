import SwiftUI
import Word7000Core

/// One goal, one button, and the little companion cheering you on. The hero
/// card holds today's progress and the way in; the practice tiles below are
/// optional extras.
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

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                    .entrance(0, distance: 10)

                if model.streakProtectionJustUsed {
                    Label {
                        Text(L.t("昨天沒有學習，連勝保護幫你保住了 \(progress.streak) 天連勝。今天學 1 個字就能延續。",
                                 "You missed yesterday, so streak protection kept your \(progress.streak)-day streak. Study one word today to keep it going."))
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "shield.lefthalf.filled").foregroundStyle(Palette.review)
                    }
                    .card(padding: 14)
                    .accessibilityIdentifier("today-streak-protected")
                }

                if let nudge = plus.nudge {
                    PlusNudgeBanner(nudge: nudge)
                        .card(padding: 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(L.practice)
                        .font(.display(.title3, weight: .bold))
                        .padding(.leading, 4)
                    if model.stats.review > 0 {
                        tile(PracticeTileItem(id: "today-review", icon: "arrow.counterclockwise", tint: Palette.miss,
                                              title: L.practiceStruggling, detail: L.t("把不熟的字練到熟", "Turn shaky words into known ones"),
                                              badge: "\(model.stats.review)") {
                            model.startStudySession(onlyIds: model.reviewWordIds)
                            start(.study)
                        }, order: 1)
                    }
                    practiceGrid
                    Text(L.studyingBank(model.bankName))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
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
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: pokes) { _, _ in model.settings.hapticsEnabled ?? true }
        .navigationTitle(L.tabToday)
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { studySettingsOpen = true } label: {
                    Image(systemName: model.settings.studyFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(L.t("學習範圍", "Study scope"))
                .accessibilityIdentifier("today-study-filter")
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        let progress = model.progress
        let plan = model.studyPlan
        let large = dynamicTypeSize.isAccessibilitySize
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        let statsLayout = large ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 18))
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.display(.subheadline, weight: .semibold))
                        .foregroundStyle(Self.cream.opacity(0.78))
                    Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                        .font(.display(.title, weight: .bold))
                        .foregroundStyle(Self.cream)
                        .contentTransition(.opacity)
                    Text(L.todayPlan(due: plan.review, fresh: plan.fresh))
                        .font(.subheadline)
                        .foregroundStyle(Self.cream.opacity(0.85))
                }
                Spacer(minLength: 0)
                // At the largest text sizes the words need the room more than the mascot does.
                if !large { mascot }
            }

            statsLayout {
                ProgressRing(fraction: model.dailyFraction, color: Self.cream, lineWidth: 11, track: Self.cream.opacity(0.22)) {
                    VStack(spacing: 0) {
                        Text("\(progress.studiedToday)")
                            .font(.display(.title, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(progress.studiedToday)))
                        Text(L.ofTarget(progress.dailyTarget))
                            .font(.display(.caption, weight: .semibold))
                            .opacity(0.8)
                    }
                    .foregroundStyle(Self.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 14)
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 8) {
                    heroChip {
                        Label {
                            Text(L.t("連續 \(progress.streak) 天", "\(progress.streak)-day streak"))
                                .contentTransition(.numericText(value: Double(progress.streak)))
                        } icon: {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.25)],
                                                                startPoint: .top, endPoint: .bottom))
                                .symbolEffect(.bounce, value: flameBounce)
                        }
                    }
                    .accessibilityLabel("\(L.streak) \(progress.streak)")
                    heroChip {
                        if model.goalDone {
                            Label(L.t("目標達成", "Goal reached"), systemImage: "checkmark.seal.fill")
                        } else {
                            Label(L.t("還差 \(left) 個", "\(left) to go"), systemImage: "target")
                                .contentTransition(.numericText(value: Double(left)))
                        }
                    }
                }
                Spacer(minLength: 0)
            }

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
                .padding(.vertical, 15)
                .background(Self.cream, in: Capsule())
                .shadow(color: PremiumSurface.umber.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(SoftPressStyle())
            .disabled(plan.total == 0)
            .opacity(plan.total == 0 ? 0.55 : 1)
            .accessibilityIdentifier("today-start")

            if model.settings.studyFilter.isActive {
                Button(L.t("調整學習範圍", "Adjust study scope")) { studySettingsOpen = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Self.cream.opacity(0.9))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background { HeroBackground(done: model.goalDone) }
        .animation(reduceMotion ? nil : Motion.reveal, value: model.goalDone)
    }

    private var mascot: some View {
        Mascot(mood: mascotMood, size: 88, hop: pokes + greetingHops)
            .overlay(alignment: .topTrailing) {
                if let bubble {
                    MascotBubble(text: bubble)
                        .frame(width: 170, alignment: .trailing)
                        .offset(y: -46)
                        .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { poke() }
    }

    private func heroChip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.display(.subheadline, weight: .semibold))
            .foregroundStyle(Self.cream)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Self.cream.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Self.cream.opacity(0.28), lineWidth: 1))
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
        var items = [
            PracticeTileItem(id: "today-quiz", icon: "checklist", tint: Palette.chinese, title: L.quickQuiz,
                             detail: L.t("\(model.settings.quizQuestionCount) 題", "\(model.settings.quizQuestionCount) questions")) { start(.quiz) },
            PracticeTileItem(id: "today-speaking", icon: "bubble.left.and.text.bubble.right.fill", tint: Palette.known, title: L.speaking,
                             detail: L.t("開口說說看", "Say it out loud")) { start(.speaking) },
        ]
        // Typing the word only makes sense when English is what is learned.
        if model.studyMode == .english {
            items.append(PracticeTileItem(id: "today-spelling", icon: "character.cursor.ibeam", tint: Palette.accent, title: L.spelling,
                                          detail: L.t("\(Spelling.sessionLength) 題", "\(Spelling.sessionLength) words")) { start(.spelling) })
        }
        items.append(PracticeTileItem(id: "today-exam", icon: "timer", tint: Palette.review, title: L.t("考前衝刺模擬", "Exam practice"),
                                      detail: L.t("限時 \(ExamView.minutes) 分鐘", "\(ExamView.minutes)-minute timed"),
                                      locked: plus.decide(.examPractice) != .allowed) { start(.exam) })
        return items
    }

    private var practiceGrid: some View {
        let items = tiles
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return VStack(spacing: 12) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(Array(rows[row].enumerated()), id: \.element.id) { offset, item in
                        tile(item, order: 2 + row * columns + offset)
                    }
                    if rows[row].count < columns {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func tile(_ item: PracticeTileItem, order: Int) -> some View {
        Button(action: item.action) {
            PracticeTile(item: item)
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

private struct PracticeTile: View {
    var item: PracticeTileItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(LinearGradient(colors: [item.tint.opacity(0.7), item.tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                    }
                    .shadow(color: item.tint.opacity(0.35), radius: 6, y: 3)
                Spacer(minLength: 4)
                if item.locked {
                    PlusBadge()
                } else if let badge = item.badge {
                    Text(badge)
                        .font(.display(.subheadline, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(item.tint, in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.tertiaryLabel)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.display(.headline, weight: .bold))
                    .foregroundStyle(.primary)
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { PremiumSurface(radius: 22) }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
