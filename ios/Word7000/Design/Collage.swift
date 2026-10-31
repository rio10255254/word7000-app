import SwiftUI
import UIKit

/// How the whole app looks. The learning, the cat and every control are the
/// same in both; only the surfaces change.
enum AppStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Warm paper and caramel leather: rounded cards, soft light and shadow.
    case leather
    /// A notebook full of cuttings: graph paper, index cards, tape, torn
    /// edges and loose charcoal lines, with no drop shadows.
    case collage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leather: L.t("皮革經典", "Leather classic")
        case .collage: L.t("紙張拼貼", "Paper collage")
        }
    }

    var detail: String {
        switch self {
        case .leather: L.t("暖紙與焦糖皮革，圓角卡片、柔和光影。", "Warm paper and caramel leather, rounded cards, soft light.")
        case .collage: L.t("方格紙、索引卡、膠帶與手繪線，像一本貼滿筆記的本子。",
                           "Graph paper, index cards, tape and hand-drawn lines, like a well-used notebook.")
        }
    }

    /// The home-screen icon that goes with it (nil: the main icon).
    var iconName: String? { self == .collage ? "AppIcon-Collage" : nil }
}

private struct AppStyleKey: EnvironmentKey {
    static let defaultValue: AppStyle = .leather
}

extension EnvironmentValues {
    /// The look chosen in Settings, for views that draw themselves differently.
    var appStyle: AppStyle {
        get { self[AppStyleKey.self] }
        set { self[AppStyleKey.self] = newValue }
    }
}

// MARK: - Paper

/// The papers a collage is cut from. Each has a light and a dark tone.
enum PaperKind {
    case graph, ruled, ivory, peach, mustard, sage

    var color: Color {
        switch self {
        case .graph: Collage.tone(0xF2F4EC, 0x2A2C27)
        case .ruled, .ivory: Collage.tone(0xFBF8F2, 0x2E2B26)
        case .peach: Collage.tone(0xF2CDB0, 0x4A3528)
        case .mustard: Collage.tone(0xDDB04E, 0x5A4620)
        case .sage: Collage.tone(0xDCE5D0, 0x2F3A2B)
        }
    }
}

enum Collage {
    static let ink = tone(0x2B2620, 0xEDE6DA)
    static let gridLine = tone(0xC9D9D2, 0x3B4943)
    static let ruleLine = tone(0xBCD0DE, 0x3A4552)
    static let margin = tone(0xE39787, 0x9A5A4E)
    static let tape = tone(0xECE0C4, 0x6B6150)
    static let clay = Palette.accent

    static func tone(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        })
    }
}

/// A sheet of paper: graph paper has a fine grid, ruled paper blue lines and
/// a red margin, the rest are plain. A faint grain lies over all of them.
struct PaperSurface: View {
    var kind: PaperKind

    var body: some View {
        kind.color
            .overlay {
                Canvas { context, size in
                    switch kind {
                    case .graph:
                        var grid = Path()
                        var x: CGFloat = 0
                        while x <= size.width { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)); x += 14 }
                        var y: CGFloat = 0
                        while y <= size.height { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)); y += 14 }
                        context.stroke(grid, with: .color(Collage.gridLine), lineWidth: 0.6)
                    case .ruled:
                        var rules = Path()
                        var y: CGFloat = 26
                        while y <= size.height { rules.move(to: CGPoint(x: 0, y: y)); rules.addLine(to: CGPoint(x: size.width, y: y)); y += 26 }
                        context.stroke(rules, with: .color(Collage.ruleLine), lineWidth: 0.8)
                        var margin = Path()
                        margin.move(to: CGPoint(x: 28, y: 0))
                        margin.addLine(to: CGPoint(x: 28, y: size.height))
                        context.stroke(margin, with: .color(Collage.margin), lineWidth: 1.2)
                    default:
                        break
                    }
                }
            }
            .overlay { PaperGrain(opacity: 0.6).blendMode(.multiply) }
    }
}

/// A rectangle with some of its edges torn: small, irregular but repeatable
/// zigzags (the same `seed` always tears the same way).
struct TornEdgeShape: Shape {
    var edges: Edge.Set = [.bottom]
    var depth: CGFloat = 4
    var seed = 1

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 9
        func jag(_ index: Int, _ side: Int) -> CGFloat {
            let value = sin(Double(index * 37 + side * 101 + seed * 13) * 12.9898) * 43758.5453
            return CGFloat(value - value.rounded(.down)) * depth
        }
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + (edges.contains(.top) ? jag(0, 0) : 0)))
        // Top, left to right.
        if edges.contains(.top) {
            var i = 1
            var x = rect.minX + step
            while x < rect.maxX { path.addLine(to: CGPoint(x: x, y: rect.minY + jag(i, 0))); x += step; i += 1 }
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right, top to bottom.
        if edges.contains(.trailing) {
            var i = 1
            var y = rect.minY + step
            while y < rect.maxY { path.addLine(to: CGPoint(x: rect.maxX - jag(i, 1), y: y)); y += step; i += 1 }
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Bottom, right to left.
        if edges.contains(.bottom) {
            var i = 1
            var x = rect.maxX - step
            while x > rect.minX { path.addLine(to: CGPoint(x: x, y: rect.maxY - jag(i, 2))); x -= step; i += 1 }
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Left, bottom to top.
        if edges.contains(.leading) {
            var i = 1
            var y = rect.maxY - step
            while y > rect.minY { path.addLine(to: CGPoint(x: rect.minX + jag(i, 3), y: y)); y -= step; i += 1 }
        }
        path.closeSubpath()
        return path
    }
}

/// A strip of masking tape.
struct TapeStrip: View {
    var width: CGFloat = 60
    var angle: Double = -6

    var body: some View {
        Rectangle()
            .fill(Collage.tape.opacity(0.82))
            .frame(width: width, height: 20)
            .overlay {
                HStack {
                    Rectangle().fill(.white.opacity(0.35)).frame(width: 1.5)
                    Spacer()
                    Rectangle().fill(.white.opacity(0.35)).frame(width: 1.5)
                }
            }
            .rotationEffect(.degrees(angle))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A loose hand-drawn charcoal line across its frame, wobbling a little.
struct InkLine: Shape {
    var seed = 1
    var wobble: CGFloat = 1.6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = max(8, Int(rect.width / 12))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for index in 1...steps {
            let t = CGFloat(index) / CGFloat(steps)
            let y = rect.midY + CGFloat(sin(Double(t) * 9 + Double(seed))) * wobble
            path.addLine(to: CGPoint(x: rect.minX + rect.width * t, y: y))
        }
        return path
    }
}

/// A charcoal scribble of loops across its frame, like an underline drawn in a hurry.
struct InkLoops: Shape {
    var count = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / CGFloat(max(1, count))
        let y = rect.maxY - rect.height * 0.3
        path.move(to: CGPoint(x: rect.minX, y: y))
        for index in 0..<count {
            let x = rect.minX + step * CGFloat(index)
            path.addCurve(to: CGPoint(x: x + step * 0.7, y: y),
                          control1: CGPoint(x: x + step * 0.2, y: rect.minY),
                          control2: CGPoint(x: x + step * 0.9, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: x + step, y: y), control: CGPoint(x: x + step * 0.5, y: rect.maxY))
        }
        return path
    }
}

/// A patch of printed halftone dots.
struct Halftone: View {
    var color: Color = Collage.ink.opacity(0.2)
    var spacing: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            var dots = Path()
            var y: CGFloat = spacing / 2
            var row = 0
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? spacing / 2 : spacing
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2))
                    x += spacing
                }
                y += spacing * 0.87
                row += 1
            }
            context.fill(dots, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A rubber stamp: two rings round a short text, pressed on at an angle.
struct StampMark<Content: View>: View {
    var color: Color = Collage.clay
    var size: CGFloat = 64
    var angle: Double = -10
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: max(2, size * 0.04))
            Circle().strokeBorder(color.opacity(0.8), lineWidth: 1).padding(size * 0.08)
            content()
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(size * 0.14)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(angle))
    }
}

extension View {
    /// Mounts the content on a piece of paper, the collage way: torn on some
    /// edges, set at a slight angle, with an optional strip of tape on top.
    /// No shadow: overlapping edges give the depth.
    func paperCard(_ kind: PaperKind, tilt: Double = 0, torn: Edge.Set = [], tape: Bool = false, seed: Int = 1) -> some View {
        background {
            PaperSurface(kind: kind)
                .clipShape(TornEdgeShape(edges: torn, depth: torn.isEmpty ? 0 : 4, seed: seed))
        }
        .overlay(alignment: .top) {
            if tape { TapeStrip(width: 64, angle: Double(seed % 2 == 0 ? 5 : -5)).offset(y: -10) }
        }
        .rotationEffect(.degrees(tilt))
    }
}

// MARK: - Choosing a style

/// A small picture of Today in a style, drawn from the same pieces the app uses.
struct StyleThumbnail: View {
    var style: AppStyle

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .topLeading) {
                Palette.background
                switch style {
                case .leather:
                    VStack(spacing: w * 0.05) {
                        RoundedRectangle(cornerRadius: w * 0.08, style: .continuous)
                            .fill(LinearGradient(colors: [Color(red: 0.77, green: 0.55, blue: 0.36), Color(red: 0.45, green: 0.29, blue: 0.19)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(alignment: .leading) {
                                Circle().trim(from: 0, to: 0.35).stroke(Color(red: 1, green: 0.95, blue: 0.88), lineWidth: w * 0.04)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: w * 0.28, height: w * 0.28)
                                    .padding(.leading, w * 0.07)
                            }
                            .frame(height: w * 0.42)
                        RoundedRectangle(cornerRadius: w * 0.06, style: .continuous).fill(Palette.surface).frame(height: w * 0.2)
                        HStack(spacing: w * 0.05) {
                            RoundedRectangle(cornerRadius: w * 0.06, style: .continuous).fill(Palette.surface)
                            RoundedRectangle(cornerRadius: w * 0.06, style: .continuous).fill(Palette.surface)
                        }
                        .frame(height: w * 0.3)
                    }
                    .padding(w * 0.07)
                case .collage:
                    VStack(spacing: w * 0.05) {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(LinearGradient(colors: [Color(red: 0.78, green: 0.54, blue: 0.36), Color(red: 0.61, green: 0.38, blue: 0.23)],
                                                     startPoint: .top, endPoint: .bottom))
                                .clipShape(TornEdgeShape(edges: [.trailing], depth: 3, seed: 2))
                            PaperSurface(kind: .graph)
                                .frame(width: w * 0.32)
                                .rotationEffect(.degrees(1.5))
                        }
                        .frame(height: w * 0.42)
                        .overlay {
                            InkLine(seed: 3, wobble: w * 0.04).stroke(Collage.ink, lineWidth: 1.4).frame(height: w * 0.1)
                        }
                        PaperSurface(kind: .ruled).frame(height: w * 0.2).rotationEffect(.degrees(-1))
                        HStack(spacing: w * 0.05) {
                            PaperSurface(kind: .graph).rotationEffect(.degrees(1))
                            PaperSurface(kind: .peach).clipShape(TornEdgeShape(edges: [.bottom], depth: 3, seed: 5))
                        }
                        .frame(height: w * 0.3)
                    }
                    .padding(w * 0.07)
                }
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The two styles side by side, each a card with its picture, name and a
/// line about it; tapping one chooses it.
struct StyleChoices: View {
    @Binding var selection: AppStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(AppStyle.allCases) { style in
                Button {
                    withAnimation(Motion.pop) { selection = style }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        StyleThumbnail(style: style)
                        HStack {
                            Text(style.label).font(.display(.headline, weight: .bold))
                            Spacer(minLength: 4)
                            Image(systemName: selection == style ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection == style ? Palette.accent : Palette.tertiaryLabel)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        Text(style.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selection == style ? Palette.accent : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(selection == style ? .isSelected : [])
                .accessibilityIdentifier("style-\(style.rawValue)")
            }
        }
    }
}

/// Settings > App style.
struct StyleSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StyleChoices(selection: Binding(
                    get: { model.settings.appStyle ?? .leather },
                    set: { model.setAppStyle($0) }
                ))
                Text(L.t("換風格只改變外觀，功能、學習紀錄和小字團都一樣。",
                         "Changing the style only changes the look; your progress, every feature and Wordling stay the same."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(Metrics.gutter)
        }
        .background { AmbientBackground() }
        .navigationTitle(L.t("App 風格", "App style"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Shown once, after the first practice: the cat asks which look you want.
struct StyleChoiceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: AppStyle = .leather

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Mascot(mood: .smug, size: 64)
                        MascotBubble(text: L.t("練完第一輪了。順便挑一下你喜歡的樣子吧，之後在設定裡也能換。",
                                               "First round done. Pick a look you like; you can change it in Settings later."),
                                     pointing: .leading)
                            .padding(.leading, 6)
                    }
                    StyleChoices(selection: $selection)
                    Button {
                        model.setAppStyle(selection)
                        dismiss()
                    } label: {
                        Text(L.t("就這個", "This one")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("style-choose")
                }
                .padding(Metrics.gutter)
            }
            .background { AmbientBackground() }
            .navigationTitle(L.t("選一個風格", "Choose a style"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .onAppear { selection = model.settings.appStyle ?? .leather }
    }
}
