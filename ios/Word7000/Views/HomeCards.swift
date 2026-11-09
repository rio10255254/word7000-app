import SwiftUI
import Word7000Core

// WordCat Next: the pieces of the home page: a stop on today's path, the
// week's stamps, the cat's can and the shelf of chapters.

/// A card's surface: leather-soft in the standard style, cut paper in the collage.
struct HomeSurface: View {
    @Environment(\.appStyle) private var appStyle
    var radius: CGFloat
    var paper: PaperKind = .ivory

    var body: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
        } else {
            PremiumSurface(radius: radius)
        }
    }
}

/// One day on the stamp card: a clay stamp once studied, a dashed ring for
/// today, the cat's can where protection saved the day.
struct DayStamp: View {
    var mark: WeekStamp.Mark
    var weekday: String
    var size: CGFloat

    var body: some View {
        ZStack {
            switch mark {
            case .studied:
                Circle().fill(Palette.accent)
                Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5).padding(2.5)
                Text(weekday).font(.system(size: size * 0.42, weight: .heavy)).foregroundStyle(.white)
            case .today:
                Circle().strokeBorder(Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [3, 2.5]))
                Text(weekday).font(.system(size: size * 0.42, weight: .heavy)).foregroundStyle(Palette.accent)
            case .covered:
                Circle().fill(Palette.review.opacity(0.2))
                Image(systemName: "fish.fill").font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(Palette.review)
            case .missed:
                Circle().fill(Palette.fill)
                Text(weekday).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(Palette.tertiaryLabel)
            case .ahead:
                Circle().strokeBorder(Palette.separator, lineWidth: 1.2)
                Text(weekday).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(Palette.tertiaryLabel)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(mark == .studied ? -8 : 0))
    }
}

/// The cat's can: full while streak protection is ready to save a missed day.
struct CatCan: View {
    var full: Bool
    var size: CGFloat

    var body: some View {
        let tint = full ? Palette.review : Palette.tertiaryLabel
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(full ? tint.opacity(0.9) : tint.opacity(0.15))
                .frame(width: size * 0.78, height: size * 0.82)
                .overlay {
                    Image(systemName: "fish.fill")
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(full ? .white : tint)
                }
                .offset(y: size * 0.12)
            Capsule()
                .fill(full ? tint : tint.opacity(0.5))
                .frame(width: size * 0.86, height: size * 0.2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The fourteen chapters as books on a shelf, each filled to how much of it
/// is mastered; the one being read is outlined.
struct Shelf: View {
    var chapters: [ShelfChapter]
    var current: Int?
    var height: CGFloat
    var bookWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                    let isCurrent = index == current
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Palette.fill)
                        .overlay(alignment: .bottom) {
                            GeometryReader { proxy in
                                let filled = proxy.size.height * min(1, chapter.fraction)
                                Rectangle()
                                    .fill(Palette.known)
                                    .frame(height: filled)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                        }
                        .overlay {
                            if isCurrent {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous).strokeBorder(Palette.accent, lineWidth: 1.5)
                            }
                        }
                        // Books of slightly different heights, like a real shelf.
                        .frame(width: bookWidth, height: height * (index % 3 == 1 ? 0.88 : index % 3 == 2 ? 0.94 : 1))
                }
            }
            Capsule()
                .fill(Color(red: 0.55, green: 0.38, blue: 0.25).opacity(0.75))
                .frame(height: 3)
        }
        .fixedSize()
    }
}

extension WeekStamps {
    /// Monday to Sunday, in the interface language.
    static func label(_ index: Int) -> String {
        L.zh ? ["一", "二", "三", "四", "五", "六", "日"][index] : ["M", "T", "W", "T", "F", "S", "S"][index]
    }
}

/// A colour sitting on a darker copy of itself, like a raised key.
struct RaisedFill<S: Shape>: View {
    var shape: S
    var tint: Color
    var depth: CGFloat = 5

    var body: some View {
        ZStack {
            shape.fill(tint).overlay(shape.fill(Color.black.opacity(0.22))).offset(y: depth)
            shape.fill(tint)
        }
    }
}

/// A stop on today's path: a round raised key. Gold with a tick once done,
/// in its colour with a soft ring when it is the one to do now, grey after.
struct PathNodeButton: View {
    enum Mark { case done, now, later }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var node: TodayNode
    var state: Mark
    var tint: Color
    var action: () -> Void
    @State private var breathe = false

    private static let gold = Color(red: 0.91, green: 0.69, blue: 0.29)

    var body: some View {
        let size: CGFloat = state == .now ? 84 : 72
        let fill = state == .done ? Self.gold : state == .now ? tint : Palette.fill
        Button(action: action) {
            Image(systemName: state == .done ? "checkmark" : node.icon)
                .font(.system(size: size * 0.38, weight: .heavy))
                .foregroundStyle(state == .later ? Palette.tertiaryLabel : .white)
                .frame(width: size, height: size * 0.92)
                .background { RaisedFill(shape: Ellipse(), tint: fill, depth: 6) }
                .padding(.bottom, 6)
        }
        .buttonStyle(SoftPressStyle())
        .background {
            if state == .now {
                Circle()
                    .strokeBorder(tint.opacity(0.25), lineWidth: 7)
                    .frame(width: size + 26, height: size + 26)
                    .scaleEffect(breathe ? 1.06 : 1)
                    .offset(y: -3)
            }
        }
        .onAppear {
            guard state == .now, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}
