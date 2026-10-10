import SwiftUI
import Word7000Core

struct HomeView: View {
    @Environment(AppModel.self) private var model
    var selectTab: (AppTab) -> Void
    var openBankPicker: () -> Void

    var body: some View {
        let stats = model.stats
        let progress = model.progress

        ScrollView {
            VStack(spacing: 14) {
                hero(stats: stats, progress: progress)

                HStack(spacing: 0) {
                    StatTile(value: progress.streak, label: L.streak, color: Palette.review)
                    Divider().frame(height: 36)
                    StatTile(value: stats.mastered, label: L.mastered, color: Palette.known)
                    Divider().frame(height: 36)
                    StatTile(value: stats.due, label: L.reviewDueToday, color: stats.due > 0 ? Palette.accent : .primary)
                }
                .card(padding: 14)
                .accessibilityIdentifier("home-stats")

                VStack(spacing: 0) {
                    Button { selectTab(.library) } label: {
                        ActionRow(icon: "magnifyingglass", tint: Palette.accent, title: L.searchPlaceholder)
                    }
                    .padding(.vertical, 10)
                    Divider().padding(.leading, 42)
                    Button {
                        model.settings.studyFilter = FilterSelection(status: .review)
                        selectTab(.study)
                    } label: {
                        ActionRow(icon: "arrow.counterclockwise", tint: Palette.review, title: L.reviewList, value: stats.review > 0 ? "\(stats.review)" : nil)
                    }
                    .padding(.vertical, 10)
                    Divider().padding(.leading, 42)
                    Button { selectTab(.quiz) } label: {
                        ActionRow(icon: "checklist", tint: Palette.chinese, title: L.quickQuiz)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .card(padding: 14)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .navigationTitle("Word7000")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BankButton(action: openBankPicker)
            }
        }
    }

    private func hero(stats: ProgressStats, progress: ProgressState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                ProgressRing(fraction: model.dailyFraction, color: model.goalDone ? Palette.known : Palette.accent) {
                    VStack(spacing: 0) {
                        Text("\(progress.studiedToday)")
                            .font(.roundedSize(34, weight: .heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("/ \(progress.dailyTarget)")
                            .font(.rounded(.footnote, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.goalDone ? L.heroDoneTitle : L.heroTitle(progress.dailyTarget))
                        .font(.roundedSize(24, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L.todayPlan(due: stats.due, fresh: model.newWordsLeftToday))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    if progress.streak > 0 {
                        Label(L.streakDays(progress.streak), systemImage: "flame.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.review)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.review.opacity(0.14), in: Capsule())
                            .padding(.top, 2)
                    }
                }
            }

            Button {
                model.startStudySession()
                selectTab(.study)
            } label: {
                Label(model.primaryActionTitle, systemImage: "book.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("home-start-study")
        }
        .card(padding: 18)
        .accessibilityIdentifier("home-today")
    }
}
