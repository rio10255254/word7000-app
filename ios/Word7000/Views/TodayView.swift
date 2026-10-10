import SwiftUI
import Word7000Core

/// One goal, one button. Everything else on this screen is optional.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    var start: (Activity) -> Void

    var body: some View {
        let stats = model.stats
        let progress = model.progress

        List {
            Section {
                VStack(spacing: 20) {
                    ProgressRing(fraction: model.dailyFraction, color: model.goalDone ? Palette.known : Palette.accent, lineWidth: 16) {
                        VStack(spacing: 0) {
                            Text("\(progress.studiedToday)")
                                .font(.roundedSize(48, weight: .bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(L.ofTarget(progress.dailyTarget))
                                .font(.rounded(.subheadline, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 170, height: 170)
                    .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                            .font(.rounded(.title2, weight: .bold))
                        Text(L.todayPlan(due: stats.due, fresh: model.newWordsLeftToday))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    Button {
                        model.ensureStudySession()
                        start(.study)
                    } label: {
                        Text(model.primaryActionTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("today-start")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            }

            Section {
                Button { start(.quiz) } label: {
                    ActionRow(icon: "checklist", tint: Palette.chinese, title: L.quickQuiz, value: L.quizLength)
                }
                .tint(.primary)
                .accessibilityIdentifier("today-quiz")
                Button { start(.speaking) } label: {
                    ActionRow(icon: "bubble.left.and.text.bubble.right.fill", tint: Palette.known, title: L.speaking)
                }
                .tint(.primary)
                .accessibilityIdentifier("today-speaking")
                if stats.review > 0 {
                    Button {
                        model.startStudySession(onlyIds: model.reviewWordIds)
                        start(.study)
                    } label: {
                        ActionRow(icon: "arrow.counterclockwise", tint: Palette.review, title: L.practiceStruggling, value: "\(stats.review)")
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("today-review")
                }
            } header: {
                Text(L.practice)
            } footer: {
                Text(L.studyingBank(model.bankName))
            }
        }
        .navigationTitle(L.tabToday)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Label(L.streakDays(progress.streak), systemImage: "flame.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(progress.streak > 0 ? Palette.review : .secondary)
                    .accessibilityLabel("\(L.streak) \(progress.streak)")
            }
        }
    }
}
