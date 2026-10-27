import SwiftUI

/// Pinyin under Chinese text in Learn Chinese mode. VoiceOver skips it: the
/// characters themselves are read aloud in Chinese.
struct PinyinLine: View {
    var text: String
    var font: Font = .subheadline

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(font)
                .foregroundStyle(Palette.accent.opacity(0.85))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }
}
