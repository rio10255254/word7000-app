import SwiftUI

/// WordCat Next: the keys at the end of every round, in one order. The
/// missed words again lead when there are any, Done is always there (never
/// only the ✕ in the corner), and another round is a quiet link under them,
/// called the same everywhere.
struct RoundEndActions: View {
    /// Words missed this round; with `reviewMissed`, going over them leads.
    var missed: Int = 0
    var reviewMissed: (() -> Void)? = nil
    var reviewTitle: String? = nil
    var reviewId = "round-review-missed"
    var done: () -> Void
    var doneId = "round-done"
    /// One more thing worth doing, under Done (today's words in a quiz).
    var extra: (() -> Void)? = nil
    var extraTitle = ""
    var extraId = "round-extra"
    var again: (() -> Void)? = nil
    var againTitle: String = L.nextSession
    var againId = "round-again"

    var body: some View {
        VStack(spacing: 12) {
            if missed > 0, let reviewMissed {
                Button(action: reviewMissed) {
                    Text(reviewTitle ?? L.practiceMissed(missed)).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.review)
                .accessibilityIdentifier(reviewId)
                Button(action: done) {
                    Text(L.done).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier(doneId)
            } else {
                Button(action: done) {
                    Text(L.done).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier(doneId)
            }
            if let extra {
                Button(action: extra) {
                    Text(extraTitle).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier(extraId)
            }
            if let again {
                Button(action: again) {
                    Text(againTitle)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftPressStyle())
                .foregroundStyle(Palette.accent)
                .accessibilityIdentifier(againId)
            }
        }
    }
}
