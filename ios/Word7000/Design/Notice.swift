import SwiftUI

// WordCat Next: every passing notice in one shape ("Stage 3", "Today's goal
// reached", "Word speaking"). It used to float over what was on screen, small
// and pale, half covering it. Now it docks at the top of the page in a solid
// colour, the cat's face beside it, and pushes the page down while it shows,
// so nothing is covered; it goes by itself, or with a tap.

/// What a notice says.
struct NoticeContent: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var detail: String? = nil
    var icon: String = "sparkles"
    var tint: Color = Palette.accent
    /// How long it stays.
    var seconds: Double = 2.4
    /// For the UI tests.
    var identifier: String = "notice"

    static func == (a: NoticeContent, b: NoticeContent) -> Bool { a.id == b.id }
}

/// The notice itself: the cat and an icon on a solid tinted card.
struct NoticeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let notice: NoticeContent
    var close: () -> Void
    @State private var hop = 0

    var body: some View {
        HStack(spacing: 12) {
            Mascot(mood: .cheer, size: 40, hop: hop)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(notice.title)
                } icon: {
                    Image(systemName: notice.icon)
                        .symbolEffect(.bounce, value: hop)
                }
                .font(.display(.headline, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                if let detail = notice.detail {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.88)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(Palette.surface)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "xmark")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Palette.surface.opacity(0.7))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(notice.tint.gradient)
                .shadow(color: notice.tint.opacity(0.35), radius: 10, y: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: close)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier(notice.identifier)
        .onAppear { if !reduceMotion { hop += 1 } }
    }
}

private struct NoticeHost: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var notice: NoticeContent?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if let shown = notice {
                    NoticeCard(notice: shown) { notice = nil }
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                        .id(shown.id)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.8), value: notice?.id)
            .task(id: notice?.id) {
                guard let shown = notice else { return }
                try? await Task.sleep(for: .seconds(shown.seconds))
                guard !Task.isCancelled, notice?.id == shown.id else { return }
                notice = nil
            }
            .sensoryFeedback(trigger: notice?.id) { _, new in
                new != nil && (model.settings.hapticsEnabled ?? true) ? .impact(weight: .light) : nil
            }
    }
}

extension View {
    /// Shows `notice` docked at the top of the page until it times out or is tapped.
    func notice(_ notice: Binding<NoticeContent?>) -> some View {
        modifier(NoticeHost(notice: notice))
    }
}
