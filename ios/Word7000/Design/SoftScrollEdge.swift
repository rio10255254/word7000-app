import SwiftUI

extension View {
    /// Content scrolling under the top of a scroll view fades out over
    /// `height` points instead of being cut off by a hard line.
    func softTopScrollEdge(_ height: CGFloat = 14) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: height)
                Rectangle().fill(.black)
            }
        }
    }
}

/// The backing for a bar of buttons at the edge of a screen or sheet: the
/// page's own paper, fading in toward the content so it slides under softly.
/// (The system bar material read as a grey-white strip on the warm paper.)
struct PaperBarBackground: View {
    @Environment(\.appStyle) private var appStyle
    /// The edge the bar sits on; the fade faces the other way.
    var edge: VerticalEdge = .bottom
    var fade: CGFloat = 18

    var body: some View {
        VStack(spacing: 0) {
            if edge == .bottom { gradient(from: .top) }
            Palette.background
                .overlay { if appStyle == .collage { PaperGrain(opacity: 0.8) } }
            if edge == .top { gradient(from: .bottom) }
        }
        .padding(edge == .bottom ? .top : .bottom, -fade)
        .ignoresSafeArea(edges: edge == .bottom ? .bottom : .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func gradient(from start: UnitPoint) -> some View {
        LinearGradient(colors: [Palette.background.opacity(0), Palette.background],
                       startPoint: start, endPoint: start == .top ? .bottom : .top)
            .frame(height: fade)
    }
}
