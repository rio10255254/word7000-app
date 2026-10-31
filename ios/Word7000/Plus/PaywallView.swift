import StoreKit
import SwiftUI
import Word7000Core

/// The Plus paywall: what it adds (the feature that brought the learner here
/// first), the two plans with the yearly one preselected, and one button.
/// Price, period and auto-renewal are always on screen, as the App Store asks.
struct PaywallView: View {
    @Environment(PlusModel.self) private var plus
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var reason: PaywallReason

    @State private var selectedID: String?
    @State private var busy = false
    @State private var purchased = false
    @State private var notice: String?
    @State private var appeared = false
    /// Bumped when a purchase or restore fails, so the button gives a small shake.
    @State private var failures = 0

    private var selected: PlusPlan? { plus.plans.first { $0.id == selectedID } ?? plus.plans.first }

    var body: some View {
        ZStack {
            if purchased {
                PlusWelcomeView { dismiss() }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                offer
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.45), value: purchased)
        .sensoryFeedback(.success, trigger: purchased)
        .sensoryFeedback(.error, trigger: failures) { _, _ in model.settings.hapticsEnabled ?? true }
        .interactiveDismissDisabled(busy)
        .task {
            if plus.plansState != .loaded { await plus.loadPlans() }
            if selectedID == nil { selectedID = plus.plans.first(where: \.yearly)?.id ?? plus.plans.first?.id }
        }
        .onAppear { withAnimation(.smooth(duration: 0.6)) { appeared = true } }
        .onChange(of: plus.subscribed) { _, subscribed in
            if subscribed { purchased = true }
        }
    }

    // MARK: The offer

    private var offer: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                plans
                    .disabled(busy)
                benefits
                Text(P.freeForever)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(alignment: .top) { PlusGlow().frame(height: 360).ignoresSafeArea() }
        .background { AmbientBackground(tint: Palette.review) }
        .safeAreaInset(edge: .bottom, spacing: 0) { purchaseBar }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.regularMaterial, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L.close)
                .accessibilityIdentifier("paywall-close")
                .disabled(busy)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            PlusIcon(size: 56, shimmer: true)
                .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .modifier(GentleFloat(active: !reduceMotion))
                // The companion cheering beside the Plus mark.
                .overlay(alignment: .bottomTrailing) {
                    Mascot(mood: .cheer, size: 42, hop: appeared ? 1 : 0)
                        .offset(x: 40, y: 10)
                        .opacity(appeared ? 1 : 0)
                }
            Text("Word7000 Plus")
                .font(.display(.title, weight: .heavy))
            Text(P.headline(reason))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let line = P.progressLine(mastered: model.stats.mastered, streak: model.progress.streak) {
                Label(line, systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.review)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Palette.review.opacity(0.12), in: Capsule())
                    .popIn(delay: 0.35)
            }
        }
    }

    private var benefits: some View {
        VStack(spacing: 0) {
            ForEach(Array(PlusBenefit.ordered(for: reason).enumerated()), id: \.element.feature) { index, benefit in
                if index > 0 { Divider().padding(.leading, 58) }
                PlusBenefitRow(benefit: benefit, highlighted: benefit.feature == reason.feature)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 14)
                    .animation(.smooth(duration: 0.5).delay(reduceMotion ? 0 : 0.12 + Double(index) * 0.07), value: appeared)
            }
        }
        .padding(.vertical, 4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        switch plus.plansState {
        case .loaded:
            VStack(spacing: 10) {
                ForEach(Array(plus.plans.enumerated()), id: \.element.id) { offset, plan in
                    PlanCard(plan: plan, selected: plan.id == selected?.id) {
                        withAnimation(reduceMotion ? nil : Motion.pop) { selectedID = plan.id }
                    }
                    .entrance(offset + 1, distance: 12)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedID)
        case .loading:
            VStack(spacing: 10) {
                ForEach(PlusPlan.samples) { plan in
                    PlanCard(plan: plan, selected: plan.yearly) {}
                }
            }
            .redacted(reason: .placeholder)
            .phaseAnimator([0.45, 1]) { content, opacity in content.opacity(opacity) } animation: { _ in .easeInOut(duration: 0.8) }
            .allowsHitTesting(false)
        case .unavailable:
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
                Text(P.plansUnavailable).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button(P.retry) { Task { await plus.loadPlans(); selectedID = plus.plans.first(where: \.yearly)?.id } }
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .card()
        }
    }

    // MARK: Purchase

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            if let notice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(Palette.review)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            Button { buy() } label: {
                ZStack {
                    Text(P.cta(selected)).font(.headline).opacity(busy ? 0 : 1)
                    if busy { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .disabled(selected == nil || busy)
            .shake(trigger: failures, enabled: !reduceMotion)
            .accessibilityIdentifier("paywall-subscribe")
            Text(P.renewalTerms(selected))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                Button(P.restore) { restore() }
                Link(L.privacyPolicy, destination: URL(string: "https://word7000-app.rio10255254.workers.dev/privacy.html")!)
                Link(P.terms, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption.weight(.medium))
            .disabled(busy)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
        .animation(.smooth, value: notice)
    }

    private func buy() {
        guard let plan = selected else { return }
        notice = nil
        busy = true
        Task {
            let outcome = await plus.purchase(plan, with: purchase)
            busy = false
            switch outcome {
            case .purchased: purchased = true
            case .pending: notice = P.pending
            case .failed: notice = P.failed; failures += 1
            case .cancelled: break
            }
        }
    }

    private func restore() {
        notice = nil
        busy = true
        Task {
            let result = await plus.restore()
            busy = false
            switch result {
            case .restored: purchased = true
            case .noneFound: notice = P.nothingToRestore
            case .failed: notice = P.restoreFailed; failures += 1
            case .cancelled: break
            }
        }
    }
}

// MARK: - Pieces

/// The Plus mark: sparkles on the accent gradient.
struct PlusIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 30
    /// A slow band of light passes over the icon now and then (the paywall's hero).
    var shimmer = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        Image(systemName: "sparkles")
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(PlusStyle.gradient, in: shape)
            .overlay {
                if shimmer && !reduceMotion {
                    ShimmerBand().clipShape(shape).allowsHitTesting(false)
                }
            }
            .shadow(color: Palette.accent.opacity(size > 40 ? 0.35 : 0), radius: 16, y: 8)
    }
}

/// A diagonal glint that sweeps across, rests, and sweeps again.
private struct ShimmerBand: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.45)
                .rotationEffect(.degrees(20))
                .phaseAnimator([false, true]) { content, across in
                    content.offset(x: across ? width * 1.3 : -width * 0.8)
                } animation: { across in
                    across ? Animation.easeInOut(duration: 0.9).delay(1.6) : Animation.linear(duration: 0.01).delay(0.2)
                }
        }
    }
}

/// Bobs gently up and down, for a hero mark that should feel alive.
private struct GentleFloat: ViewModifier {
    var active: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([false, true]) { view, up in
                view.offset(y: up ? -4 : 2)
            } animation: { _ in Animation.easeInOut(duration: 2.2) }
        } else {
            content
        }
    }
}

enum PlusStyle {
    /// Ochre warming into terracotta, like polished copper.
    static let gradient = LinearGradient(colors: [Palette.review, Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// A soft, slowly drifting wash of the Plus colors behind the header.
struct PlusGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle().fill(Palette.accent.opacity(0.28))
                    .frame(width: 260).offset(x: -70 + sin(t / 3) * 30, y: -60 + cos(t / 4) * 20)
                Circle().fill(Palette.chinese.opacity(0.24))
                    .frame(width: 240).offset(x: 90 + cos(t / 3.5) * 30, y: -30 + sin(t / 2.5) * 20)
            }
            .blur(radius: 60)
            .frame(maxWidth: .infinity)
        }
        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        .accessibilityHidden(true)
    }
}

struct PlusBenefit {
    var feature: PlusFeature
    var icon: String
    var title: String
    var detail: String

    static var all: [PlusBenefit] {
        [
            PlusBenefit(feature: .smartAI, icon: "sparkles", title: P.benefitSmartAI, detail: P.benefitSmartAIDetail),
            PlusBenefit(feature: .scan, icon: "doc.text.viewfinder", title: P.benefitScan, detail: P.benefitScanDetail),
            PlusBenefit(feature: .sync, icon: "icloud.fill", title: P.benefitSync, detail: P.benefitSyncDetail),
            PlusBenefit(feature: .history, icon: "chart.line.uptrend.xyaxis", title: P.benefitHistory, detail: P.benefitHistoryDetail),
            PlusBenefit(feature: .examPractice, icon: "timer", title: P.benefitExam, detail: P.benefitExamDetail),
        ]
    }

    /// The feature the learner just reached for goes first.
    static func ordered(for reason: PaywallReason) -> [PlusBenefit] {
        guard let feature = reason.feature else { return all }
        return all.filter { $0.feature == feature } + all.filter { $0.feature != feature }
    }
}

struct PlusBenefitRow: View {
    var benefit: PlusBenefit
    var highlighted = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: benefit.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(highlighted ? .white : Palette.accent)
                .frame(width: 32, height: 32)
                .background(highlighted ? AnyShapeStyle(PlusStyle.gradient) : AnyShapeStyle(Palette.accent.opacity(0.12)), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.title).font(.subheadline.weight(.semibold))
                Text(benefit.detail).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// One plan: radio, name, what it comes to per month, and the price.
struct PlanCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var plan: PlusPlan
    var selected: Bool
    var choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Palette.accent : Palette.tertiaryLabel)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: reduceMotion ? false : selected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.yearly ? P.yearly : P.monthly).font(.headline)
                    Text(plan.perMonth.map(P.perMonth) ?? P.monthlyDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(plan.displayPrice).font(.display(.title3, weight: .bold)).monospacedDigit()
                    Text(plan.yearly ? P.perYear : P.perMonthUnit).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : Palette.separator.opacity(0.5), lineWidth: selected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if plan.monthsSaved > 0 {
                    Text(P.saveMonths(plan.monthsSaved))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.review, in: Capsule())
                        .shadow(color: Palette.review.opacity(0.35), radius: 4, y: 2)
                        .offset(x: -14, y: -10)
                }
            }
            .shadow(color: Palette.accent.opacity(selected ? 0.22 : 0), radius: 12, y: 6)
            .scaleEffect(selected ? 1 : 0.98)
            .animation(reduceMotion ? nil : Motion.pop, value: selected)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(plan.yearly ? "plan-yearly" : "plan-monthly")
    }
}

/// After a purchase: a short celebration and what is now unlocked.
struct PlusWelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var done: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                PlusBurst()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(PlusStyle.gradient)
                    .symbolEffect(.bounce, value: shown)
                    .popIn()
            }
            VStack(spacing: 8) {
                Text(P.welcomeTitle).font(.display(.largeTitle, weight: .heavy))
                Text(P.welcomeText).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .entrance(2)
            VStack(alignment: .leading, spacing: 12) {
                // Each unlocked feature ticks in, one after another.
                ForEach(Array(PlusBenefit.all.enumerated()), id: \.element.feature) { offset, benefit in
                    Label(benefit.title, systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.body.weight(.medium))
                        .entrance(offset + 4, distance: 10)
                }
            }
            .padding(.top, 4)
            Spacer()
            Button(action: done) {
                Text(P.welcomeStart).font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground(tint: Palette.review) }
        .overlay(alignment: .top) {
            if !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .onAppear { shown = true }
    }
}

/// Dots that fly out once, like a small burst of confetti.
struct PlusBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    private let colors: [Color] = [Palette.accent, Palette.chinese, Palette.review, Palette.known]

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                let angle = Double(index) / 18 * 2 * .pi
                let distance: CGFloat = index.isMultiple(of: 2) ? 120 : 92
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index % colors.count])
                    .frame(width: index.isMultiple(of: 3) ? 6 : 9, height: index.isMultiple(of: 3) ? 12 : 9)
                    .rotationEffect(.degrees(fired ? Double(index) * 40 : 0))
                    .offset(x: fired ? cos(angle) * distance : 0, y: fired ? sin(angle) * distance : 0)
                    .opacity(fired ? 0 : 1)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.1).delay(0.1)) { fired = true }
        }
    }
}
