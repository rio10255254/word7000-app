import SwiftUI
import Word7000Core

/// WordCat Next: today's words and speaking are both done. Dark leather,
/// a gold stamp with the streak pressed down, the week's stamps, the cat's
/// can, and a way to keep it or share it. Once a day.
struct DayCompleteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// In turn: the stamp is down, its streak rolls on to today's, and
    /// today's square of the week is stamped gold.
    @State private var stamped = false
    @State private var rolled = false
    @State private var todayStamped = false
    /// When the cat's dance last started: it dances again every few seconds.
    @State private var danceStart: Double = 0

    static let gold = Color(red: 0.95, green: 0.78, blue: 0.45)
    private static let cream = Color(red: 1.0, green: 0.96, blue: 0.88)

    var body: some View {
        // Scrolls only when it does not fit (an SE, large text), so Keep it
        // is always reachable; otherwise the page fills the screen as before.
        GeometryReader { proxy in
            ScrollView {
                page
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { background }
        .overlay(alignment: .top) {
            if rolled, !reduceMotion { ConfettiBurst(colors: ConfettiBurst.gold).allowsHitTesting(false).ignoresSafeArea() }
        }
        // A second popper as today's square is stamped.
        .overlay(alignment: .top) {
            if todayStamped, !reduceMotion { ConfettiBurst(colors: ConfettiBurst.paper).allowsHitTesting(false).ignoresSafeArea() }
        }
        .task {
            guard !stamped else { return }
            guard !reduceMotion else {
                withAnimation(.easeOut(duration: 0.3)) { stamped = true; rolled = true; todayStamped = true }
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { stamped = true }
                try await Task.sleep(for: .milliseconds(480))
                withAnimation(.snappy(duration: 0.5)) { rolled = true }
                try await Task.sleep(for: .milliseconds(520))
                withAnimation(Motion.pop) { todayStamped = true }
                // The cat keeps dancing while the screen is up.
                while !Task.isCancelled {
                    danceStart = Date().timeIntervalSinceReferenceDate
                    try await Task.sleep(for: .seconds(MascotAntic.dance.duration + 1.4))
                }
            } catch { return }
        }
        .sensoryFeedback(.success, trigger: stamped) { _, new in new && haptics }
        .sensoryFeedback(.impact(weight: .medium), trigger: todayStamped) { _, new in new && haptics }
        .soundEffect(trigger: stamped) { (_: Bool, now: Bool) -> SoundEffect? in now ? .stamp : nil }
        .soundEffect(trigger: rolled) { (_: Bool, now: Bool) -> SoundEffect? in now ? .complete : nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-complete")
    }

    private var page: some View {
        let streak = model.progress.streak
        return VStack(spacing: 22) {
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                Text(L.t("今天的份完成！", "Today's done!"))
                    .font(.display(.largeTitle, weight: .heavy))
                    .foregroundStyle(Self.cream)
                HStack(spacing: 16) {
                    Label(L.t("單字 \(model.progress.studiedToday) 個", "\(model.progress.studiedToday) words"), systemImage: "checkmark")
                    if model.homeShowsSpeaking {
                        Label(L.t("口說過關", "Speaking"), systemImage: "checkmark")
                    }
                }
                .font(.headline)
                .foregroundStyle(Self.cream.opacity(0.8))
            }
            .entrance(0)
            stamp(streak)
                .padding(.vertical, 8)
                // The cat dances beside its stamp.
                .overlay(alignment: .bottomTrailing) {
                    Mascot(mood: .cheer, size: 78, antic: danceStart > 0 ? .dance : nil, anticStart: danceStart)
                        .offset(x: 18, y: 18)
                        .opacity(rolled ? 1 : 0)
                        .scaleEffect(rolled || reduceMotion ? 1 : 0.4, anchor: .bottom)
                        .accessibilityHidden(true)
                }
            week
                .entrance(2)
            Text(canLine)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Self.cream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(3)
            Spacer(minLength: 8)
            VStack(spacing: 12) {
                Button {
                    model.noteDayCompleteShown()
                    dismiss()
                } label: {
                    Text(L.t("收下", "Keep it"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.3, green: 0.19, blue: 0.1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Self.gold, in: Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityIdentifier("day-complete-keep")
                ShareLink(item: shareText) {
                    Label(L.t("分享", "Share"), systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(Self.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Self.cream.opacity(0.1), in: Capsule())
                        .overlay(Capsule().strokeBorder(Self.cream.opacity(0.25), lineWidth: 1))
                }
                .simultaneousGesture(TapGesture().onEnded { Usage.log("day_complete_share") })
                .accessibilityIdentifier("day-complete-share")
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(maxWidth: .infinity)
    }

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    /// The streak as a gold stamp, pressed down with a little bounce; its
    /// number then rolls on from yesterday's with a burst of gold.
    private func stamp(_ streak: Int) -> some View {
        let shown = rolled ? streak : max(0, streak - 1)
        return ZStack {
            Sunburst(color: Self.gold.opacity(0.28), rays: 16, size: 360)
                .opacity(stamped ? 1 : 0)
                .scaleEffect(rolled || reduceMotion ? 1 : 0.6)
            Circle()
                .fill(RadialGradient(colors: [Self.gold.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 150))
                .frame(width: 300, height: 300)
                .opacity(stamped ? 1 : 0)
            Circle()
                .strokeBorder(Self.gold, lineWidth: 7)
                .frame(width: 190, height: 190)
            Circle()
                .strokeBorder(Self.gold.opacity(0.6), lineWidth: 1.5)
                .frame(width: 168, height: 168)
            if rolled, !reduceMotion {
                SparkleBurst(color: Self.gold, radius: 58).scaleEffect(2)
            }
            VStack(spacing: 0) {
                Text("\(shown)")
                    .font(.displaySize(76, weight: .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown)))
                Text(L.t("連續天數", "day streak"))
                    .font(.display(.headline, weight: .bold))
            }
            .foregroundStyle(Self.gold)
        }
        .rotationEffect(.degrees(stamped ? -8 : -20))
        .scaleEffect(stamped ? 1 : (reduceMotion ? 1 : 2.1))
        .opacity(stamped ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("連續 \(streak) 天", "\(streak)-day streak"))
        .accessibilityIdentifier("day-complete-stamp")
    }

    /// Monday to Sunday, gold where studied, with the cat's can at the end.
    private var week: some View {
        HStack(spacing: 8) {
            ForEach(Array(model.weekStamps.enumerated()), id: \.offset) { index, day in
                // Today's square is stamped last, after the streak.
                let landing = day.date == model.today && !todayStamped
                let studied = day.mark == .studied && !landing
                Text(WeekStamps.label(index))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(studied ? Color(red: 0.3, green: 0.19, blue: 0.1) : Self.cream.opacity(0.55))
                    .frame(width: 34, height: 34)
                    .background {
                        if studied {
                            Circle().fill(Self.gold)
                        } else if day.mark == .covered {
                            Circle().fill(Palette.review.opacity(0.35))
                        } else {
                            Circle().strokeBorder(Self.cream.opacity(0.3), lineWidth: 1.5)
                        }
                    }
                    .scaleEffect(landing && !reduceMotion ? 0.82 : 1)
            }
            CatCan(full: model.catCanReady, size: 32)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("這週學了 \(model.weekStamps.filter { $0.mark == .studied }.count) 天", "\(model.weekStamps.filter { $0.mark == .studied }.count) days this week"))
    }

    private var canLine: String {
        if model.catCanReady {
            return L.t("貓罐頭在你這：漏學 1 天也不會斷。", "You have a Cat Can: miss a day and your streak is safe.")
        }
        guard let ready = model.streakProtectionReadyOn else { return "" }
        let parts = ready.split(separator: "-").compactMap { Int($0) }
        let date = parts.count == 3 ? "\(parts[1])/\(parts[2])" : ready
        return L.t("貓罐頭 \(date) 回來，這幾天別漏掉喔。", "Your Cat Can is back on \(date). Don't miss a day till then.")
    }

    private var shareText: String {
        L.t("我在單字貓連續學了 \(model.progress.streak) 天，今天背了 \(model.progress.studiedToday) 個字！",
            "\(model.progress.streak) days in a row on WordCat: \(model.progress.studiedToday) words today!")
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.27, green: 0.18, blue: 0.12), Color(red: 0.12, green: 0.08, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
            PaperGrain(opacity: 1).blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}
