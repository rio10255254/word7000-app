import SwiftUI
import Word7000Core

/// Today's AI learning insights, kept for the day so the Me page and the
/// companion share one request.
enum InsightsStore {
    private struct Saved: Codable {
        var day: String
        var mode: String
        var insights: CloudAI.Insights
    }
    private static let key = "word7000.aiInsights"

    static func today(mode: StudyMode) -> CloudAI.Insights? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              saved.day == DayMath.today(), saved.mode == mode.rawValue else { return nil }
        return saved.insights
    }

    static func save(_ insights: CloudAI.Insights, mode: String) {
        guard let data = try? JSONEncoder().encode(Saved(day: DayMath.today(), mode: mode, insights: insights)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// The companion telling you, in its own words, how your learning is going:
/// the day's AI insights as a short chat. It thinks for a moment (or reads
/// what it worked out earlier today), then its messages type in one by one:
/// the headline, the summary, what is going well, the words to work on with a
/// tip for each, and the next few days. The words can be practised at once.
struct MascotChatSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Called with the focus words' ids when the learner wants to practise them.
    var practise: ([String]) -> Void

    @State private var insights: CloudAI.Insights?
    @State private var loading = false
    @State private var failure: CloudAI.Failure?
    @State private var askCloud = false
    /// How many of the messages have typed in so far.
    @State private var shown = 0
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .bottom, spacing: 10) {
                        Mascot(mood: mood, size: 60, hop: shown)
                        ChatLine(text: insights == nil
                                 ? L.t("讓我看看你最近有多認真……", "Let's see how hard you've really been working…")
                                 : L.t("看完了。嗯，我有一些話要說。", "Done. Right. I have some thoughts."))
                    }
                    .padding(.bottom, 4)

                    if let insights {
                        let lines = messages(insights)
                        ForEach(Array(lines.prefix(shown).enumerated()), id: \.offset) { _, line in
                            line.view
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        }
                        if shown < lines.count { TypingDots() }
                        if shown >= lines.count {
                            practiceButton(insights)
                            Text(L.t("由 Claude 線上 AI 根據最近 14 天的紀錄產生，可能有誤。明天會再更新。",
                                     "Written by Anthropic's Claude from the last 14 days, and may contain mistakes. Refreshes tomorrow."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                            PlusAIUpsell()
                        }
                    } else if loading {
                        TypingDots()
                    } else if let failure {
                        AIFailureNote(failure: failure)
                        Button(L.t("再試一次", "Try again"), action: start)
                            .secondaryAction()
                    }
                }
                .padding(Metrics.gutter)
                .animation(reduceMotion ? nil : Motion.reveal, value: shown)
            }
            .background { AmbientBackground() }
            .navigationTitle(L.t("小字團說", "Wordling says"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.done) { dismiss() } }
            }
        }
        .compactSheet()
        .task {
            if let saved = InsightsStore.today(mode: model.studyMode) {
                present(saved)
            } else {
                start()
            }
        }
        .onDisappear { revealTask?.cancel() }
        .cloudConsentAlert(isPresented: $askCloud) {
            if IntelligenceSettings.shared.cloudConsent == true { start() } else { dismiss() }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: shown) { _, new in
            new > 0 && (model.settings.hapticsEnabled ?? true)
        }
    }

    private var mood: Mascot.Mood {
        if loading { return .thinking }
        if failure != nil { return .encourage }
        return insights == nil ? .idle : .happy
    }

    private func start() {
        guard !loading else { return }
        if CloudAssistant.shared.needsConsent { askCloud = true; return }
        let mode = model.studyMode.rawValue
        let input = model.insightsInput()
        loading = true
        failure = nil
        Task {
            defer { loading = false }
            do {
                let value = try await CloudAssistant.shared.run(.insights, input, as: CloudAI.Insights.self).cleaned()
                InsightsStore.save(value, mode: mode)
                present(value)
            } catch is CancellationError {
            } catch {
                failure = (error as? CloudAI.Failure) ?? .unavailable
            }
        }
    }

    /// Shows the insights, typing the messages in one after another.
    private func present(_ value: CloudAI.Insights) {
        insights = value
        let total = messages(value).count
        guard !reduceMotion else { shown = total; return }
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            for step in 1...max(1, total) {
                try? await Task.sleep(for: .milliseconds(step == 1 ? 350 : 650))
                guard !Task.isCancelled else { return }
                shown = step
            }
        }
    }

    private struct Message {
        var view: AnyView
    }

    private func messages(_ insights: CloudAI.Insights) -> [Message] {
        var list: [Message] = []
        list.append(Message(view: AnyView(ChatLine(text: insights.headline, emphasis: true))))
        if !insights.summary.isEmpty { list.append(Message(view: AnyView(ChatLine(text: insights.summary)))) }
        if !insights.strengths.isEmpty {
            list.append(Message(view: AnyView(ChatCard(title: L.t("做得好的地方", "Going well"), tint: Palette.known, symbol: "checkmark.circle.fill") {
                ForEach(insights.strengths, id: \.self) { Text($0).font(.subheadline) }
            })))
        }
        if !insights.focusWords.isEmpty {
            list.append(Message(view: AnyView(ChatCard(title: L.t("這幾個字要加油", "Words to work on"), tint: Palette.review, symbol: "target") {
                ForEach(insights.focusWords, id: \.word) { focus in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(focus.word).font(.display(.headline, weight: .bold))
                        if !focus.tip.isEmpty { Text(focus.tip).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
            })))
        }
        if !insights.plan.isEmpty {
            list.append(Message(view: AnyView(ChatCard(title: L.t("接下來幾天", "Next few days"), tint: Palette.accent, symbol: "calendar") {
                ForEach(Array(insights.plan.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Palette.accent, in: Circle())
                        Text(step).font(.subheadline)
                    }
                }
            })))
        }
        return list
    }

    @ViewBuilder
    private func practiceButton(_ insights: CloudAI.Insights) -> some View {
        let ids = model.wordIds(forPrompts: insights.focusWords.map(\.word))
        if !ids.isEmpty {
            Button { practise(ids) } label: {
                Label(L.t("現在練習這 \(ids.count) 個字", "Practise these \(ids.count) words now"), systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .padding(.top, 6)
            .accessibilityIdentifier("mascot-chat-practice")
        }
    }
}

/// One message from the companion: a cream bubble with a tail on its left.
private struct ChatLine: View {
    var text: String
    var emphasis = false

    var body: some View {
        Text(text)
            .font(emphasis ? .display(.headline, weight: .bold) : .body)
            .foregroundStyle(emphasis ? Palette.accent : Color.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18,
                                       style: .continuous)
                    .fill(MascotBubble.cream)
                    .shadow(color: PremiumSurface.umber.opacity(0.12), radius: 6, y: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A longer message with a small heading: what's going well, words, the plan.
private struct ChatCard<Content: View>: View {
    var title: String
    var tint: Color
    var symbol: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18,
                                   style: .continuous)
                .fill(MascotBubble.cream)
                .shadow(color: PremiumSurface.umber.opacity(0.12), radius: 6, y: 3)
        }
    }
}

/// Three dots bouncing in turn: the companion is typing.
private struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .offset(y: reduceMotion ? 0 : -CGFloat(abs(sin(t * 6 - Double(index) * 0.7))) * 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(MascotBubble.cream, in: Capsule())
        .accessibilityLabel(L.t("小字團正在想", "Wordling is thinking"))
    }
}
