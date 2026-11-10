import SwiftUI
import Word7000Core

/// At the end of the first launch: keep the classic layout (the default:
/// Today's practice tiles, pick what to practise) or try easy mode (the app
/// lays out each day: cards, writing, quiz, speaking). Either can be changed
/// later in Settings → Layout.
struct LayoutChoiceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var classic = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 10) {
                    Mascot(mood: .happy, size: 64)
                    MascotBubble(text: L.t("最後一題：你喜歡自己挑，還是我幫你排？", "Last one: pick for yourself, or let me plan it?"),
                                 pointing: .leading)
                }
                .accessibilityElement(children: .combine)
                Text(L.t("你想怎麼學？", "How do you want to learn?"))
                    .font(.display(.largeTitle, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                option(classic: true,
                       icon: "square.grid.2x2.fill",
                       title: L.t("經典模式", "Classic"),
                       badge: L.t("預設", "Default"),
                       detail: L.t("首頁就是練習磚塊：翻卡、看字選意思、口說、拼字、模擬考，想練什麼自己挑。",
                                   "Today is your practice tiles: cards, quizzes, speaking, writing, mock exams. Pick what you feel like."))
                option(classic: false,
                       icon: "wand.and.stars",
                       title: L.t("懶人模式", "Easy mode"),
                       badge: nil,
                       detail: L.t("每天幫你排好一條路：翻卡 → 寫字 → 考考看 → 口說，照著按下一步就好。",
                                   "Each day is laid out for you: cards → writing → quiz → speaking. Just tap Next."))
                Text(L.t("之後隨時可以在「設定 → 版面」換。", "You can switch any time in Settings → Layout."))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                model.setClassicLayout(classic)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text(L.t("就這樣開始", "Let's start"))
                    Image(systemName: "arrow.right")
                }
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .prominentAction()
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 12)
            .accessibilityIdentifier("layout-choice-start")
        }
        .background { AmbientBackground(tint: Palette.accent).ignoresSafeArea() }
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: classic) { _, _ in model.settings.hapticsEnabled ?? true }
    }

    private func option(classic value: Bool, icon: String, title: String, badge: String?, detail: String) -> some View {
        let chosen = classic == value
        return Button {
            withAnimation(reduceMotion ? nil : Motion.pop) { classic = value }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(LinearGradient(colors: [Palette.accent.opacity(chosen ? 0.75 : 0.45), Palette.accent.opacity(chosen ? 1 : 0.6)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.display(.title2, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Palette.known, in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryLabel)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(chosen ? Palette.accent : Palette.tertiaryLabel)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(18)
            .background {
                PremiumSurface(radius: 22)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(chosen ? Palette.accent : Color.clear, lineWidth: 2.5)
                    }
            }
            .scaleEffect(chosen && !reduceMotion ? 1 : 0.98)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier(value ? "layout-choice-classic" : "layout-choice-easy")
    }
}
