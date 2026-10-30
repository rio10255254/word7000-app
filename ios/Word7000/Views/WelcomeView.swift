import SwiftUI
import Word7000Core

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: StudyMode = .english
    @State private var target = 20
    @State private var waved = false
    var finish: (StudyMode, Int, Bool) -> Void

    private var chinese: Bool { mode == .english }
    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // The companion says hello with a hop.
                        Mascot(mood: .happy, size: 96, hop: waved ? 1 : 0)
                            .popIn()
                        Text("Word7000").font(.largeTitle.bold())
                            .entrance(1)
                        Text(text("先從 5 個單字開始", "Start with 5 words"))
                            .font(.title2.bold())
                            .contentTransition(.opacity)
                            .entrance(2)
                        FloatingWords(learningEnglish: mode == .english)
                            .entrance(3)
                    }
                    .padding(.vertical, 16)
                    .animation(reduceMotion ? nil : Motion.reveal, value: mode)
                    .listRowBackground(Color.clear)
                }
                Section(text("我想學習", "I want to learn")) {
                    Picker(text("語言", "Language"), selection: $mode) {
                        Text("英文 English").tag(StudyMode.english)
                        Text("中文 Chinese").tag(StudyMode.chinese)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("welcome-language")
                }
                Section(text("每日目標", "Daily goal")) {
                    Picker(text("單字數量", "Words"), selection: $target) {
                        ForEach([10, 20, 30, 50], id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button { finish(mode, target, true) } label: {
                        Label(text("開始 5 字練習", "Try 5 words"), systemImage: "arrow.right")
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("welcome-start")
                    .listRowBackground(Color.clear)
                    Button(text("先看看字庫", "Explore the words first")) { finish(mode, target, false) }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("welcome-skip")
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background { AmbientBackground() }
        }
        .sensoryFeedback(.selection, trigger: mode)
        .sensoryFeedback(.selection, trigger: target)
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            if !reduceMotion { waved = true }
        }
    }
}

/// A few sample words bobbing gently under the title, in the language the
/// learner picked. Decoration only.
private struct FloatingWords: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var learningEnglish: Bool

    private static let words: [(english: String, chinese: String, tint: Color)] = [
        ("brave", "勇敢的", Palette.accent),
        ("journey", "旅程", Palette.known),
        ("bright", "明亮的", Palette.review),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.words.indices, id: \.self) { index in
                let word = Self.words[index]
                let chip = Text(learningEnglish ? word.english : word.chinese)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(word.tint)
                    .contentTransition(.opacity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(word.tint.opacity(0.14), in: Capsule())
                if reduceMotion {
                    chip
                } else {
                    // Each chip keeps its own slow rhythm so they never move in step.
                    chip.phaseAnimator([false, true]) { content, up in
                        content.offset(y: up ? -4 : 2)
                    } animation: { _ in
                        .easeInOut(duration: 1.5 + Double(index) * 0.35)
                    }
                }
            }
        }
        .padding(.top, 4)
        .accessibilityHidden(true)
    }
}
