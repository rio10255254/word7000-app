import SwiftUI
import Word7000Core

// WordCat Next: the pieces of the home page around the big card. The
// other pillar as one row, the week's stamps with the shelf of chapters,
// the four big buttons and the notes that only show when they apply.
// Big type and few words: each piece says one thing.

/// The pillar that is not the big card, as one row: tap it to start, or
/// make it the one to do first.
struct PillarRow: View {
    var icon: String
    var tint: Color
    var title: String
    var detail: String
    var done: Bool
    var compact: Bool
    /// "Do this first": swaps the cards. Nil once it is done.
    var leadTitle: String?
    var lead: (() -> Void)?
    var open: () -> Void
    var openId: String
    var leadId: String
    /// The cat is suggesting this one to a new learner.
    var suggested = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    Image(systemName: done ? "checkmark" : icon)
                        .font(.system(size: compact ? 17 : 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: compact ? 40 : 46, height: compact ? 40 : 46)
                        .background(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.display(compact ? .headline : .title3, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(detail)
                            .font(compact ? .footnote : .subheadline)
                            .foregroundStyle(done ? tint : Palette.secondaryLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityValue(suggested ? L.t("傻貓推薦", "Silly Cat suggests") : "")
            .accessibilityIdentifier(openId)
            if let leadTitle, let lead {
                Button(action: lead) {
                    Text(leadTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(tint.opacity(0.14), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityIdentifier(leadId)
            } else if done {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 8 : 10)
        .background { HomeSurface(radius: 22, paper: .sage) }
    }
}

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

/// A step of a pillar, as a chip on the big card: done, the one now, or later.
struct HeroStepChip: View {
    enum Mark { case done, now, later }
    var icon: String
    var title: String
    var state: Mark
    var compact: Bool

    private static let cream = Color(red: 1.0, green: 0.97, blue: 0.91)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state == .done ? "checkmark" : icon)
                .font(.caption.weight(.heavy))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.display(compact ? .footnote : .subheadline, weight: .bold))
        .foregroundStyle(state == .now ? Color(red: 0.4, green: 0.25, blue: 0.15) : Self.cream.opacity(state == .later ? 0.75 : 1))
        .frame(maxWidth: .infinity, minHeight: compact ? 32 : 38)
        .padding(.horizontal, 6)
        .background {
            Capsule().fill(state == .now ? Self.cream : Self.cream.opacity(state == .done ? 0.22 : 0.08))
        }
        .overlay {
            if state == .later {
                Capsule().strokeBorder(Self.cream.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            }
        }
        .contentShape(Capsule())
    }
}

/// The week as a card of stamps (Monday to Sunday) and the cat's can, with
/// the shelf of chapters underneath: how far through the list.
struct HomeProgressCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var compact: Bool
    var flameBounce: Int
    var openShelf: () -> Void

    var body: some View {
        let stamps = model.weekStamps
        let chapters = model.shelfChapters
        let mastered = chapters.reduce(0) { $0 + $1.mastered }
        let total = chapters.reduce(0) { $0 + $1.total }
        let current = MasteryShelf.current(chapters)
        let studiedDays = stamps.filter { $0.mark == .studied }.count
        VStack(spacing: compact ? 10 : 14) {
            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.75, blue: 0.3), Color(red: 0.93, green: 0.42, blue: 0.2)],
                                                        startPoint: .top, endPoint: .bottom))
                        .symbolEffect(.bounce, value: flameBounce)
                    Text("\(model.progress.streak)")
                        .font(.display(compact ? .title3 : .title2, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(model.progress.streak)))
                    Text(L.t("天", "d"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.secondaryLabel)
                }
                .fixedSize()
                Spacer(minLength: 2)
                HStack(spacing: compact ? 4 : 6) {
                    ForEach(Array(stamps.enumerated()), id: \.offset) { index, stamp in
                        DayStamp(mark: stamp.mark, weekday: Self.weekday(index), size: compact ? 24 : 28)
                    }
                    CatCan(full: model.catCanReady, size: compact ? 22 : 26)
                        .padding(.leading, 2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.t("連續 \(model.progress.streak) 天，這週學了 \(studiedDays) 天。", "\(model.progress.streak)-day streak, \(studiedDays) days this week.")
                                + (model.catCanReady ? L.t("貓罐頭在，漏一天也能保住紀錄。", " The cat's can is ready to save a missed day.") : ""))
            .accessibilityIdentifier("today-week")

            Button(action: openShelf) {
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L.t("已掌握", "Mastered"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondaryLabel)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(mastered.formatted())
                                .font(.display(compact ? .title3 : .title2, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(mastered)))
                            Text("/ \(total.formatted())")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.secondaryLabel)
                                .monospacedDigit()
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    .fixedSize()
                    Spacer(minLength: 4)
                    Shelf(chapters: chapters, current: current, height: compact ? 26 : 32)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.t("已掌握 \(mastered) 個字，共 \(total) 個", "\(mastered) of \(total) words mastered")
                                + (current.map { L.t("，正在讀第 \($0 + 1) 章", ", reading chapter \($0 + 1)") } ?? ""))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("today-shelf")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, compact ? 10 : 14)
        .background { HomeSurface(radius: 22, paper: .ruled) }
    }

    static func weekday(_ index: Int) -> String {
        L.zh ? ["一", "二", "三", "四", "五", "六", "日"][index] : ["M", "T", "W", "T", "F", "S", "S"][index]
    }
}

/// One day on the stamp card: a clay stamp once studied, a dashed ring for
/// today, the cat's can where protection saved the day.
private struct DayStamp: View {
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
private struct Shelf: View {
    var chapters: [ShelfChapter]
    var current: Int?
    var height: CGFloat

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
                        .frame(width: 10, height: height * (index % 3 == 1 ? 0.88 : index % 3 == 2 ? 0.94 : 1))
                }
            }
            Capsule()
                .fill(Color(red: 0.55, green: 0.38, blue: 0.25).opacity(0.75))
                .frame(height: 3)
        }
        .fixedSize()
    }
}

/// One of the big buttons along the bottom: an icon and a word.
struct QuickButton: View {
    var icon: String
    var title: String
    var tint: Color
    var badge: String?
    var locked = false
    var minHeight: CGFloat
    var maxHeight: CGFloat?
    var bounce = 0

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: bounce)
                .frame(width: 42, height: 42)
                .background(LinearGradient(colors: [tint.opacity(0.72), tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: tint.opacity(0.28), radius: 4, y: 2)
            Text(title)
                .font(.display(.subheadline, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight)
        .background { HomeSurface(radius: 20, paper: .ivory) }
        .overlay(alignment: .topTrailing) {
            if locked {
                PlusBadgeFitting().padding(6)
            } else if let badge {
                Text(badge)
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tint, in: Capsule())
                    .padding(6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// A note that only shows when it applies: Sunday's quiz, the month before
/// the exam.
struct HomeNoteCard: View {
    var icon: String
    var tint: Color
    var title: String
    var detail: String
    var locked = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(.headline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryLabel)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if locked {
                PlusBadgeFitting()
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { HomeSurface(radius: 20, paper: .mustard) }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
