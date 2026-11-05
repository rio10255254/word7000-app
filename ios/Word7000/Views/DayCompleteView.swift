import SwiftUI
import Word7000Core

/// WordCat Next: today's words and speaking are both done. Dark leather,
/// a gold stamp with the streak pressed down, the week's stamps, the cat's
/// can, and a way to keep it or share it. Once a day.
struct DayCompleteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = false

    static let gold = Color(red: 0.95, green: 0.78, blue: 0.45)
    private static let cream = Color(red: 1.0, green: 0.96, blue: 0.88)

    var body: some View {
        let streak = model.progress.streak
        VStack(spacing: 22) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { background }
        .onAppear {
            guard !stamped else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.45, dampingFraction: 0.55).delay(0.35)) { stamped = true }
        }
        .sensoryFeedback(.success, trigger: stamped) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-complete")
    }

    /// The streak as a gold stamp, pressed down with a little bounce.
    private func stamp(_ streak: Int) -> some View {
        ZStack {
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
            VStack(spacing: 0) {
                Text("\(streak)")
                    .font(.displaySize(76, weight: .heavy))
                    .monospacedDigit()
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
                let studied = day.mark == .studied
                Text(HomeProgressCard.weekday(index))
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
            }
            CatCan(full: model.catCanReady, size: 32)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("這週學了 \(model.weekStamps.filter { $0.mark == .studied }.count) 天", "\(model.weekStamps.filter { $0.mark == .studied }.count) days this week"))
    }

    private var canLine: String {
        if model.catCanReady {
            return L.t("貓罐頭在你這：哪天忘了，牠會幫你保住紀錄。", "The cat's can is yours: miss a day and it keeps your streak.")
        }
        guard let ready = model.streakProtectionReadyOn else { return "" }
        let parts = ready.split(separator: "-").compactMap { Int($0) }
        let date = parts.count == 3 ? "\(parts[1])/\(parts[2])" : ready
        return L.t("貓罐頭 \(date) 回來。這幾天別漏掉喔。", "The cat's can is back on \(date). Don't miss a day till then.")
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
