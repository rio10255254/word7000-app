import SwiftUI
import Word7000Core

/// One goal, one button. Everything else on this screen is optional.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var studySettingsOpen = false

    var start: (Activity) -> Void

    var body: some View {
        let stats = model.stats
        let progress = model.progress
        let plan = model.studyPlan

        List {
            Section {
                VStack(spacing: 16) {
                    ProgressRing(fraction: model.dailyFraction, color: model.goalDone ? Palette.known : Palette.accent, lineWidth: 16) {
                        VStack(spacing: 0) {
                            Text("\(progress.studiedToday)")
                                .font(.rounded(.largeTitle, weight: .bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(L.ofTarget(progress.dailyTarget))
                                .font(.rounded(.subheadline, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        // Large text shrinks to stay inside the ring.
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, 20)
                    }
                    .frame(width: 142, height: 142)
                    .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                            .font(.rounded(.title2, weight: .bold))
                        Text(L.todayPlan(due: plan.review, fresh: plan.fresh))
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
                    .disabled(plan.total == 0)
                    .accessibilityIdentifier("today-start")
                    if model.settings.studyFilter.isActive {
                        Button(L.t("調整學習範圍", "Adjust study scope")) { studySettingsOpen = true }
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            }

            if model.streakProtectionJustUsed {
                Section {
                    Label {
                        Text(L.t("昨天沒有學習，連勝保護幫你保住了 \(progress.streak) 天連勝。今天學 1 個字就能延續。",
                                 "You missed yesterday, so streak protection kept your \(progress.streak)-day streak. Study one word today to keep it going."))
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "shield.lefthalf.filled").foregroundStyle(Palette.review)
                    }
                    .accessibilityIdentifier("today-streak-protected")
                }
            }

            if let nudge = plus.nudge {
                Section {
                    PlusNudgeBanner(nudge: nudge)
                        .padding(.vertical, 4)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Section {
                Button { start(.quiz) } label: {
                    ActionRow(icon: "checklist", tint: Palette.chinese, title: L.quickQuiz,
                              value: L.t("\(model.settings.quizQuestionCount) 題", "\(model.settings.quizQuestionCount) questions"))
                }
                .tint(.primary)
                .accessibilityIdentifier("today-quiz")
                Button { start(.speaking) } label: {
                    ActionRow(icon: "bubble.left.and.text.bubble.right.fill", tint: Palette.known, title: L.speaking)
                }
                .tint(.primary)
                .accessibilityIdentifier("today-speaking")
                // Typing the word only makes sense when English is what is learned.
                if model.studyMode == .english {
                    Button { start(.spelling) } label: {
                        ActionRow(icon: "character.cursor.ibeam", tint: Palette.accent, title: L.spelling,
                                  value: L.t("\(Spelling.sessionLength) 題", "\(Spelling.sessionLength) words"))
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("today-spelling")
                }
                Button { start(.exam) } label: {
                    ActionRow(icon: "timer", tint: Palette.review, title: L.t("考前衝刺模擬", "Exam practice"),
                              locked: plus.decide(.examPractice) != .allowed)
                }
                .tint(.primary)
                .accessibilityIdentifier("today-exam")
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
        .animation(reduceMotion ? nil : Motion.reveal, value: plus.nudge)
        .navigationTitle(L.tabToday)
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { studySettingsOpen = true } label: {
                    Image(systemName: model.settings.studyFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(L.t("學習範圍", "Study scope"))
                .accessibilityIdentifier("today-study-filter")
            }
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
