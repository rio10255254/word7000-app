import SwiftUI
import Word7000Core

struct WelcomeView: View {
    @State private var mode: StudyMode = WelcomeView.suggestedMode
    @State private var target = 20
    var finish: (StudyMode, Int, Bool) -> Void

    private var chinese: Bool { mode == .english }

    /// A phone set to Chinese most likely belongs to a learner of English;
    /// any other language, to a learner of Chinese. UI tests keep English.
    static var suggestedMode: StudyMode {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingOnboarding") { return .english }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == false ? .chinese : .english
    }

    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "books.vertical.fill")
                            .font(.largeTitle).foregroundStyle(Palette.accent)
                        Text("Word7000").font(.largeTitle.bold())
                        Text(text("先從 5 個單字開始", "Start with 5 words"))
                            .font(.title2.bold())
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
                Section(text("我想學習", "I want to learn")) {
                    Picker(text("語言", "Language"), selection: $mode) {
                        Text("英文 English").tag(StudyMode.english)
                        Text("中文 Chinese").tag(StudyMode.chinese)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("welcome-language")
                    Text(text("中文介面，用中文意思學 7000 個英文單字。之後可以在首頁切換。",
                              "An English interface for learning the Chinese for 7000 English words, with pinyin. Switch any time on the Today screen."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            .background(Palette.background)
        }
    }
}
