import SwiftUI

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
