import SwiftUI
import AVFoundation
import Word7000Core

struct SpeechSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loading = true

    private var preferences: SpeechPreferences { model.settings.speech ?? SpeechPreferences() }

    var body: some View {
        Form {
            Group {
                if !loading, Self.canSoundBetter {
                    // Apps cannot download voices; the learner can, for free.
                    Section {
                        // The icon sits by the title, not halfway down the paragraph.
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "waveform.badge.plus").foregroundStyle(Palette.accent)
                                .font(.title3).padding(.top, 2)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L.t("下載更自然的聲音", "Get a more natural voice")).font(.headline)
                                Text(L.t("iPhone 內建的標準聲音比較生硬。到 iPhone「設定 → 輔助使用 → 朗讀內容 → 聲音」，下載英文的 Ava（優質）和中文（台灣）的美佳（增強），單字貓會自動改用。",
                                         "The built-in standard voices sound flat. In iPhone Settings → Accessibility → Spoken Content → Voices, download English › Ava (Premium) and Chinese (Taiwan) › Meijia (Enhanced). WordCat switches to them automatically."))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("speech-better-voice")
                    }
                }
                Section {
                    voiceRow(language: "en-US", title: L.t("英文聲音", "English voice"))
                    voiceRow(language: "zh-TW", title: L.t("中文聲音", "Chinese voice"))
                } footer: {
                    Text(L.t("更多聲音可在 iPhone「設定 → 輔助使用」下載。", "Download more voices in iPhone Settings → Accessibility."))
                }
                Section(L.t("語速", "Reading speed")) {
                    Picker(L.t("語速", "Reading speed"), selection: Binding(get: { preferences.speed }, set: { value in
                        var next = preferences
                        next.speed = value
                        model.settings.speech = next
                    })) {
                        Text(L.t("慢速", "Slow")).tag(SpeechSpeed.slow)
                        Text(L.t("自然", "Natural")).tag(SpeechSpeed.natural)
                        Text(L.t("稍快", "Brisk")).tag(SpeechSpeed.brisk)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("speech-speed")
                }
                Section(L.t("試聽", "Preview")) {
                    preview(language: "en-US", title: L.t("試聽英文", "Preview English"), text: "Take your time. A little practice each day makes a real difference.")
                    preview(language: "zh-TW", title: L.t("試聽中文", "Preview Chinese"), text: "慢慢來，每天練習一點，就能看見自己的進步。")
                }
                Section {
                    Toggle(L.t("學習卡自動發音", "Read cards aloud"), isOn: Binding(get: { preferences.autoSpeak ?? false }, set: { value in
                        var next = preferences
                        next.autoSpeak = value
                        model.settings.speech = next
                    }))
                    .accessibilityIdentifier("speech-auto-speak")
                    Toggle(L.t("口說題目自動朗讀", "Read speaking questions aloud"), isOn: Binding(get: { preferences.autoReadQuestions ?? true }, set: { value in
                        var next = preferences
                        next.autoReadQuestions = value
                        model.settings.speech = next
                    }))
                    .accessibilityIdentifier("speech-auto-read-questions")
                } footer: {
                    Text(L.t("每翻到新的一張學習卡，就自動唸出卡片正面；口說練習換到新題目時，也會先唸一次題目。", "Each new study card is read aloud as it appears, and each new speaking question is read once."))
                }
            }
            .listRowBackground(StyledRowBackground())
        }
        .warmList()
        .navigationTitle(L.t("朗讀聲音", "Reading voice"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .onChange(of: model.settings.speech) { _, _ in Speaker.shared.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reload() } } }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
            Task { await reload() }
        }
        .onDisappear { Speaker.shared.stop() }
        .sensoryFeedback(.selection, trigger: preferences.speed) { _, _ in model.settings.hapticsEnabled ?? true }
    }

    /// Only standard voices installed for English or Taiwan Mandarin.
    private static var canSoundBetter: Bool {
        ["en-US", "zh-TW"].contains {
            SpeechVoiceSelection.canSoundBetter(Speaker.shared.voices, language: $0,
                                                enhancedQuality: AVSpeechSynthesisVoiceQuality.enhanced.rawValue)
        }
    }

    private func reload() async {
        await Speaker.shared.refreshVoices()
        withAnimation(reduceMotion ? nil : Motion.reveal) { loading = false }
    }

    private func voiceRow(language: String, title: String) -> some View {
        let selectedName = Speaker.shared.selectedVoice(language: language, preferences: preferences)?.name ?? L.t("自動", "Automatic")
        return NavigationLink {
            SpeechVoicePicker(language: language, title: title)
        } label: {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                if loading { ProgressView() }
                else {
                    Text(selectedName)
                        .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        .transition(.opacity)
                }
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(loading ? L.t("載入中", "Loading") : selectedName)
        .accessibilityIdentifier("speech-voice-\(language)")
    }

    private func preview(language: String, title: String, text: String) -> some View {
        let playing = Speaker.shared.activeText == text && Speaker.shared.activeLanguage == language
        return Button {
            Speaker.shared.speak(text, language: language, preferences: preferences)
        } label: {
            Label {
                Text(playing ? L.t("停止試聽", "Stop preview") : title)
            } icon: {
                // The play symbol turns into rippling waves while the sample is read.
                Image(systemName: playing ? "speaker.wave.3.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating, isActive: playing && !reduceMotion)
            }
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("speech-preview-\(language)")
    }
}

private struct SpeechVoicePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var language: String
    var title: String
    private var preferences: SpeechPreferences { model.settings.speech ?? SpeechPreferences() }

    var body: some View {
        List {
            Group {
                Section {
                    Button { choose(nil) } label: {
                        HStack {
                            Text(L.t("自動選擇高品質聲音", "Automatic voice selection")).foregroundStyle(.primary)
                            Spacer()
                            if preferences.voiceID(for: language) == nil { Image(systemName: "checkmark").popIn() }
                        }
                    }
                }
                Section(L.t("已下載的聲音", "Downloaded voices")) {
                    ForEach(SpeechVoiceSelection.matching(Speaker.shared.voices, language: language)) { voice in
                        Button { choose(voice.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(voice.name).foregroundStyle(.primary)
                                    Text("\(Locale(identifier: L.zh ? "zh_Hant_TW" : "en_US").localizedString(forIdentifier: voice.language) ?? voice.language) · \(quality(voice.quality))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if preferences.voiceID(for: language) == voice.id { Image(systemName: "checkmark").popIn() }
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("speech-pick-\(voice.id)")
                    }
                }
            }
            .listRowBackground(StyledRowBackground())
        }
        .warmList()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func quality(_ value: Int) -> String {
        value >= AVSpeechSynthesisVoiceQuality.premium.rawValue ? L.t("優質", "Premium")
            : value >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue ? L.t("增強", "Enhanced") : L.t("標準", "Standard")
    }

    private func choose(_ id: String?) {
        var next = preferences
        if language.hasPrefix("en") { next.englishVoiceID = id } else { next.chineseVoiceID = id }
        model.settings.speech = next
        dismiss()
    }
}
