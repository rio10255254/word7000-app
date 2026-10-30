import SwiftUI
import Word7000Core

/// "Plus" with a small lock, next to features that are locked right now.
struct PlusBadge: View {
    var locked = true

    var body: some View {
        HStack(spacing: 3) {
            if locked { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)) }
            Text(P.plusBadge).font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(PlusStyle.gradient, in: Capsule())
        .accessibilityLabel(locked ? P.lockedLabel : P.plusBadge)
    }
}

/// Plus status and the way in, at the top of "我".
struct PlusSection: View {
    var compact = false
    @Environment(PlusModel.self) private var plus
    @State private var manageOpen = false

    var body: some View {
        Section {
          if compact {
            Button {
                if plus.subscribed { manageOpen = true } else { plus.paywallReason = .general }
            } label: {
                HStack(spacing: 12) {
                    PlusIcon(size: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline).foregroundStyle(.primary)
                        if case let .trial(daysLeft) = plus.access {
                            Text("\(P.trialDaysMeter(daysLeft)) · \(P.scansLeft(plus.policy.trialScansLeft))")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("me-plus")
          } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    PlusIcon(size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if case let .trial(daysLeft) = plus.access {
                    trialMeters(daysLeft: daysLeft)
                }
                if plus.subscribed {
                    Button(P.manage) { manageOpen = true }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Button { plus.paywallReason = .general } label: {
                        VStack(spacing: 1) {
                            Text(plus.access == .expired ? P.unlockPlus : P.upgradePlus).font(.headline)
                            if let from = startingPrice {
                                Text(P.priceFrom(from)).font(.caption).opacity(0.85)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("me-plus")
                }
            }
            .padding(.vertical, 6)
          }
        }
        .manageSubscriptionsSheet(isPresented: $manageOpen)
    }

    private func trialMeters(daysLeft: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            meter(label: P.trialDaysMeter(daysLeft), fraction: 1 - plus.policy.trialFraction(), tint: daysLeft <= 2 ? Palette.review : Palette.accent)
            meter(label: P.trialScansMeter(plus.policy.trialScansLeft), fraction: Double(plus.policy.trialScansLeft) / Double(PlusPolicy.trialScanLimit),
                  tint: plus.policy.trialScansLeft <= 1 ? Palette.review : Palette.accent)
        }
    }

    private func meter(label: String, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            SessionBarTinted(fraction: fraction, tint: tint)
        }
    }

    private var title: String {
        switch plus.access {
        case .subscribed: P.memberTitle
        case .trial: P.trialTitle
        case .expired: "Word7000 Plus"
        }
    }

    private var subtitle: String {
        switch plus.access {
        case .subscribed: P.memberDetail(planYearly: plus.activePlanID == PlusModel.productIDs[1], endsAt: plus.periodEndsAt)
        case .trial: P.trialDetail
        case .expired: P.statusExpired
        }
    }

    /// The lowest per-month price on offer, e.g. the yearly plan's.
    private var startingPrice: String? {
        plus.plans.first(where: \.yearly)?.perMonth ?? plus.plans.first?.displayPrice
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(P.nudgeTitle(nudge)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text(P.nudgeText(nudge)).font(.footnote).foregroundStyle(.secondary)
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
                Image(systemName: "hourglass")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(PlusStyle.gradient)
                    .symbolEffect(.bounce, value: shown)
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
            .background(.bar)
        }
        .background { AmbientBackground(tint: Palette.review) }
        .onAppear {
            shown = true
            plus.noteTrialRecapSeen()
        }
    }
}
