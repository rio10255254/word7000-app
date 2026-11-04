import SwiftUI
import Word7000Core

/// "Premium" with a small lock, next to features that are locked right now.
struct PlusBadge: View {
    var locked = true
    /// Only the lock, for a spot too narrow for the word: "Premium" is never
    /// squeezed into a column of single letters.
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            if locked || compact { Image(systemName: "lock.fill").font(.system(size: compact ? 10 : 9, weight: .bold)) }
            if !compact { Text(P.plusBadge).font(.caption.weight(.bold)) }
        }
        .lineLimit(1)
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 7)
        .padding(.vertical, compact ? 5 : 3)
        .background(PlusStyle.gradient, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(locked ? P.lockedLabel : P.plusBadge)
    }
}

/// The Premium badge where it fits whole, else just its lock.
struct PlusBadgeFitting: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            PlusBadge()
            PlusBadge(compact: true)
        }
    }
}

/// A thin capsule meter in any tint, with a soft glow on the filled part.
struct SessionBarTinted: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.fill)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, proxy.size.width * min(1, max(0, fraction))))
                    .shadow(color: tint.opacity(0.3), radius: 3)
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.82), value: fraction)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// A reminder on Today when the trial is nearly over or the scans run out.
struct PlusNudgeBanner: View {
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var nudge: PlusPolicy.Nudge
    /// Bumped once the banner has settled, so its icon gives a small nod.
    @State private var nod = 0

    var body: some View {
        HStack(spacing: 12) {
            Button {
                plus.paywallReason = PaywallReason(nudge)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: P.nudgeIcon(nudge))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(nudge == .trialEnded ? AnyShapeStyle(PlusStyle.gradient) : AnyShapeStyle(Palette.review.gradient), in: Circle())
                        .symbolEffect(.bounce, value: nod)
                    // A guest's first step is signing in, so their progress is kept.
                    let guest = plus.needsSignIn && nudge == .trialEnded
                    VStack(alignment: .leading, spacing: 2) {
                        Text(guest ? L.t("用 Apple 登入，保存你的進度", "Sign in with Apple to keep your progress") : P.nudgeTitle(nudge)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text(guest ? P.guestNudgeText : P.nudgeText(nudge)).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier("plus-nudge")
            Button {
                withAnimation(.snappy) { plus.dismissNudge() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Palette.fill, in: Circle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(L.close)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            if !reduceMotion { nod += 1 }
        }
    }
}

/// Covers a Plus screen with a blurred preview and one way to unlock it.
struct PlusLockedOverlay: View {
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var feature: PlusFeature
    /// Bumped once the card has risen, so the lock gives a little jiggle.
    @State private var jiggle = 0

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: jiggle)
                .frame(width: 52, height: 52)
                .background(PlusStyle.gradient, in: Circle())
                .shadow(color: Palette.accent.opacity(0.35), radius: 10, y: 4)
                .popIn(delay: 0.15)
            Text(P.lockedTitle(feature)).font(.display(.title3, weight: .bold)).multilineTextAlignment(.center)
            Text(P.lockedText(feature)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { plus.paywallReason = .locked(feature) } label: {
                Text(P.unlockPlus).font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("locked-unlock")
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        .padding(.horizontal, 28)
        .entrance(0, distance: 24)
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            if !reduceMotion { jiggle += 1 }
        }
    }
}

/// Shown once when the trial ends: what the week added up to, what stays
/// free, and what Plus keeps going.
struct TrialRecapView: View {
    @Environment(PlusModel.self) private var plus
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var seePlans: () -> Void
    @State private var shown = false

    var body: some View {
        let week = model.history(days: PlusPolicy.trialDays)
        ScrollView {
            VStack(spacing: 22) {
                // The companion holding up the trial's hourglass.
                Mascot(mood: .happy, size: 84, hop: shown ? 1 : 0)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(PlusStyle.gradient)
                            .symbolEffect(.bounce, value: shown)
                            .padding(7)
                            .background(Palette.surface, in: Circle())
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                            .offset(x: 10, y: 4)
                    }
                    .popIn()
                    .padding(.top, 28)
                let hasWeek = week.studied + week.activeDays + plus.trialScansUsed > 0
                VStack(spacing: 8) {
                    Text(P.recapTitle).font(.display(.title, weight: .heavy))
                    if hasWeek {
                        Text(P.recapText).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .entrance(1)
                if hasWeek {
                HStack(spacing: 0) {
                    StatTile(value: week.studied, label: P.recapCards, color: Palette.accent)
                    Divider().frame(height: 36)
                    StatTile(value: week.activeDays, label: P.recapDays, color: Palette.review)
                    Divider().frame(height: 36)
                    StatTile(value: plus.trialScansUsed, label: P.recapScans, color: Palette.known)
                }
                .card(padding: 14)
                .entrance(2)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(P.recapKeepTitle).font(.subheadline.weight(.semibold))
                    ForEach(P.recapFreeItems, id: \.self) { item in
                        Label(item, systemImage: "checkmark").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Divider().padding(.vertical, 2)
                    Text(P.recapPlusTitle).font(.subheadline.weight(.semibold))
                    ForEach(PlusBenefit.all, id: \.feature) { benefit in
                        Label {
                            Text(benefit.title).font(.subheadline)
                        } icon: {
                            Image(systemName: "lock.fill").foregroundStyle(Palette.chinese)
                        }
                    }
                }
                .card()
                .entrance(3)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    dismiss()
                    seePlans()
                } label: {
                    Text(P.seePlans).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("plus-recap-plans")
                Button(P.recapLater) { dismiss() }
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("plus-recap-later")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .background { PaperBarBackground() }
        }
        .background { AmbientBackground(tint: Palette.review) }
        .onAppear {
            shown = true
            plus.noteTrialRecapSeen()
        }
    }
}

/// An invitation to Plus right where it would help: what it would do here,
/// and the App Store's free trial when the plans have one. Hidden for
/// subscribers. `compact` drops the card for use inside a list row.
struct PlusUpsellCard: View {
    @Environment(PlusModel.self) private var plus
    @Environment(\.appStyle) private var appStyle
    var feature: PlusFeature
    var title: String
    var detail: String
    var compact = false
    @State private var paywall: PaywallReason?

    var body: some View {
        if !plus.subscribed {
            Button { paywall = .locked(feature) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(PlusStyle.gradient, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("PREMIUM")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PlusStyle.gradient, in: Capsule())
                        }
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(offer)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.review)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 10)
                }
                .padding(compact ? 0 : 14)
                .background { if !compact { surface } }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier("plus-upsell-\(feature.rawValue)")
            .sheet(item: $paywall) { PaywallView(reason: $0) }
            .task { if plus.plansState != .loaded { await plus.loadPlans() } }
        }
    }

    private var offer: String {
        if let days = plus.plans.compactMap(\.freeTrialDays).first {
            return L.t("免費試用 \(days) 天，隨時取消 →", "Try free for \(days) days, cancel anytime →")
        }
        return L.t("看看 Premium →", "See Premium →")
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: .mustard)
                .opacity(0.55)
                .background(PaperKind.ivory.color)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 3, seed: 13))
                .overlay(alignment: .topTrailing) { TapeStrip(width: 40, angle: 8).offset(x: -18, y: -10) }
        } else {
            PremiumSurface(radius: 20)
        }
    }
}

/// Free and Plus side by side, so the difference is plain.
struct PlusComparison: View {
    private struct Line: Identifiable {
        var id: String { name }
        var name: String
        var free: Bool
    }

    private var lines: [Line] {
        [
            Line(name: L.t("背 7000 單字、複習、測驗、拼字、口說", "Taiwan Mandarin words, reviews, quizzes, writing, speaking"), free: true),
            Line(name: L.t("登入後保存與同步進度", "Keeping and syncing progress (signed in)"), free: true),
            Line(name: L.t("傻貓 AI：聊天、解說、口說教練", "Silly Cat's AI: chat, explanations, speaking coach"), free: false),
            Line(name: L.t("掃描單字表與手寫筆記", "Scanning word lists and handwriting"), free: false),
            Line(name: L.t("15 分鐘模擬考", "15-minute mock exams"), free: false),
            Line(name: L.t("完整學習紀錄與弱點單字", "Full history and weak words"), free: false),
        ]
    }

    /// Wide enough for "Premium" on one line, growing with the text size.
    @ScaledMetric(relativeTo: .caption) private var column: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Text(L.t("免費", "Free")).frame(width: column)
                Text("Premium").frame(width: column)
            }
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
            ForEach(lines) { line in
                HStack(spacing: 8) {
                    Text(line.name)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    mark(line.free).frame(width: column)
                    mark(true).frame(width: column)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.fill).frame(height: 1) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plus-comparison")
    }

    private func mark(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "minus")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(on ? Palette.known : Color.secondary.opacity(0.5))
            .accessibilityLabel(on ? L.t("有", "Yes") : L.t("沒有", "No"))
    }
}
