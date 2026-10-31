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
                Section {
                    voiceRow(language: "en-US", title: L.t("英文聲音", "English voice"))
                    voiceRow(language: "zh-TW", title: L.t("中文聲音", "Chinese voice"))
                } footer: {
                    Text(L.t("自動選擇會優先使用已下載的高品質聲音。可在 iPhone 的「設定 → 輔助使用」中下載更多朗讀聲音，再回到這裡選擇。", "Automatic uses the best downloaded voice for the language. You can download more reading voices in iPhone Settings under Accessibility, then return here to choose one."))
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
                } footer: {
                    Text(L.t("每翻到新的一張學習卡，就自動唸出卡片正面。", "Each new study card is read aloud as it appears."))
                }
            }
            .listRowBackground(Palette.surface)
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
            .listRowBackground(Palette.surface)
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
