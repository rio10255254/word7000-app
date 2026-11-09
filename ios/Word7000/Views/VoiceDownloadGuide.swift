import SwiftUI
import AVFoundation
import Word7000Core

/// How to download the iPhone's natural voice, drawn as the screens of the
/// iPhone's Settings app: each step shows the row to tap there, ringed.
/// An app cannot open Accessibility › Spoken Content itself (Apple only lets
/// it open its own page in Settings), so the first step is the way back from
/// that page, and the search box is the shortcut.
struct VoiceDownloadGuide: View {
    /// Whether the voice to download is the Chinese one.
    var learningChinese: Bool
    /// Whether the guide is written in Chinese.
    var chinese: Bool

    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            step(1, text("按下面的「打開設定」，會先到單字貓自己的頁面。按左上角「‹ 設定」回到最上層。",
                         "Open Settings below lands on WordCat's own page. Tap ‹ Settings at the top left to go back to the main list.")) {
                backBar
            }
            step(2, text("往下滑，點「輔助使用」", "Scroll down and tap Accessibility")) {
                row(icon: "accessibility", tint: .blue, title: text("輔助使用", "Accessibility"))
            }
            step(3, text("點「朗讀內容」，再點「聲音」", "Tap Spoken Content, then Voices")) {
                VStack(spacing: 6) {
                    row(icon: "text.bubble.fill", tint: .gray, title: text("朗讀內容", "Spoken Content"))
                    row(icon: nil, tint: .gray, title: text("聲音", "Voices"))
                }
            }
            step(4, learningChinese ? text("點「中文」→「美佳」，下載「增強」那個", "Tap Chinese → Meijia, and download Enhanced")
                                    : text("點「英文」→「Ava」，下載「優質」那個", "Tap English → Ava, and download Premium")) {
                row(icon: nil, tint: .gray,
                    title: learningChinese ? text("美佳（增強）", "Meijia (Enhanced)") : text("Ava（優質）", "Ava (Premium)"),
                    download: true)
            }
            step(5, text("回到單字貓。下載好我會自動換上，不用再設定。", "Come back to WordCat. Once it's in, I switch to it by myself."), mock: nil)
            Label(text("找不到？在設定最上面的搜尋欄打「朗讀內容」。檔案有點大，建議連 Wi-Fi，背景下載時可以先學。",
                       "Lost? Type Spoken Content in the search box at the top of Settings. It's a big file, so Wi-Fi is best; you can study while it downloads."),
                  systemImage: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("voice-download-guide")
    }

    private func step(_ number: Int, _ caption: String, @ViewBuilder mock: () -> some View) -> some View {
        step(number, caption, mock: AnyView(mock()))
    }

    private func step(_ number: Int, _ caption: String, mock: AnyView?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Palette.surface)
                .frame(width: 26, height: 26)
                .background(Palette.accent, in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text(caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
                if let mock {
                    mock.padding(.trailing, 6)
                }
            }
        }
    }

    // MARK: Settings, drawn

    /// The top of WordCat's page in Settings, the way back ringed.
    private var backBar: some View {
        HStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").font(.subheadline.weight(.semibold))
                Text(text("設定", "Settings")).font(.subheadline)
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay { tapRing }
            Spacer()
            Text(text("單字貓", "WordCat")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(mockBackground)
    }

    /// A row of a Settings list, ringed: the one to tap.
    private func row(icon: String?, tint: Color, title: String, download: Bool = false) -> some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(title).font(.subheadline).foregroundStyle(Palette.ink)
            Spacer(minLength: 6)
            Image(systemName: download ? "icloud.and.arrow.down" : "chevron.right")
                .font(download ? .body.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(download ? Color.blue : Color.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(mockBackground)
        .overlay { tapRing }
    }

    private var mockBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    private var tapRing: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Palette.accent, lineWidth: 2)
            .padding(-2)
    }
}

/// WordCat Next: a small strip on the speaking pages while the iPhone still
/// reads with its flat standard voice: what is read aloud there that is not
/// one of the stages' recordings (follow-ups, hints, words) sounds far better
/// with the free natural voice. A tap opens the steps; the cross puts it away
/// for a week. It goes for good once the voice is in.
struct VoiceTipStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// "en-US" or "zh-TW": the voice that reads this page.
    var language: String
    @State private var open = false
    @State private var hidden = false
    /// The voices are listed: before that, every voice looks missing.
    @State private var loaded = false

    private var shows: Bool {
        guard loaded, !AppRuntime.uiTesting, !hidden else { return false }
        if let until = model.settings.voiceTipHiddenUntil, until > model.today { return false }
        return SpeechVoiceSelection.canSoundBetter(Speaker.shared.voices, language: language,
                                                   enhancedQuality: AVSpeechSynthesisVoiceQuality.enhanced.rawValue)
    }

    var body: some View {
        Group {
            if shows {
                HStack(spacing: 10) {
                    Button { open = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.badge.plus")
                                .font(.headline)
                                .foregroundStyle(Palette.surface)
                                .frame(width: 32, height: 32)
                                .background(Palette.accent.gradient, in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L.t("聲音太像機器人？", "Sounds robotic?"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Palette.ink)
                                Text(L.t("免費換成 iPhone 的自然聲音", "Get the iPhone's natural voice, free"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.accent)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Palette.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityIdentifier("voice-tip")
                    Button {
                        withAnimation(reduceMotion ? nil : Motion.reveal) { hidden = true }
                        model.settings.voiceTipHiddenUntil = DayMath.addDays(model.today, 7)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Palette.secondaryLabel)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(L.t("一週後再提醒", "Remind me in a week"))
                    .accessibilityIdentifier("voice-tip-later")
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 8)
                .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.accent.opacity(0.35), lineWidth: 1))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $open) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L.t("情境對話是真人錄音；追問、提示和單字由 iPhone 朗讀。下載一次自然聲音（免費），這些也會好聽很多。",
                                 "The scenes are recorded by real people; follow-ups, hints and words are read by the iPhone. Download its natural voice once (free) and those sound far better too."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        VoiceDownloadGuide(learningChinese: language.hasPrefix("zh"), chinese: L.zh)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        } label: {
                            Label(L.t("打開設定", "Open Settings"), systemImage: "gear")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .prominentAction()
                        .accessibilityIdentifier("voice-tip-open-settings")
                    }
                    .padding(Metrics.gutter)
                }
                .navigationTitle(L.t("換成自然的聲音", "A natural voice"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L.done) { open = false }
                    }
                }
                .background { AmbientBackground() }
            }
        }
        .task {
            await Speaker.shared.refreshVoices()
            loaded = true
        }
        // Back from Settings: once the voice is in, the strip goes by itself.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await Speaker.shared.refreshVoices(fresh: true) } }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: shows)
    }
}
