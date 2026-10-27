import SwiftUI
import Word7000Core

/// One goal, one button. Everything else on this screen is optional.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var studySettingsOpen = false
    @ScaledMetric(relativeTo: .title) private var ringSize = 92.0

    var start: (Activity) -> Void

    var body: some View {
        let stats = model.stats
        let progress = model.progress
        let plan = model.studyPlan

        List {
            Section {
                VStack(spacing: 14) {
                    // Ring and plan side by side keep the day's practice on
                    // screen even on the smallest iPhone.
                    HStack(spacing: 18) {
                        ProgressRing(fraction: model.dailyFraction, color: model.goalDone ? Palette.known : Palette.accent, lineWidth: 11) {
                            VStack(spacing: 0) {
                                Text("\(progress.studiedToday)")
                                    .font(.rounded(.title, weight: .bold))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                Text(L.ofTarget(progress.dailyTarget))
                                    .font(.rounded(.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            // Large text shrinks to stay inside the ring.
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, 14)
                        }
                        .frame(width: min(ringSize, 140), height: min(ringSize, 140))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                                .font(.rounded(.title3, weight: .bold))
                            Text(L.todayPlan(due: plan.review, fresh: plan.fresh))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
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
                // Learners of English type the word; learners of Chinese read
                // the characters and type their pinyin.
                if model.studyMode == .english {
                    Button { start(.spelling) } label: {
                        ActionRow(icon: "character.cursor.ibeam", tint: Palette.accent, title: L.spelling,
                                  value: L.t("\(Spelling.sessionLength) 題", "\(Spelling.sessionLength) words"))
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("today-spelling")
                } else {
                    Button { start(.spelling) } label: {
                        ActionRow(icon: "character.phonetic", tint: Palette.accent, title: L.pinyinPractice,
                                  value: L.t("\(Spelling.sessionLength) 題", "\(Spelling.sessionLength) words"))
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("today-pinyin")
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
                // The built-in list needs no reminder; a bank of one's own does.
                if model.activeSet != nil { Text(L.studyingBank(model.bankName)) }
            }
        }
        .listSectionSpacing(.compact)
        .animation(reduceMotion ? nil : Motion.reveal, value: plus.nudge)
        .navigationTitle(L.tabToday)
        // The mode switch takes the title's place, so the whole day fits on
        // one screen; the tab bar already says where this is.
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet() }
        .toolbar {
            ToolbarItem(placement: .principal) { StudyModeSwitch() }
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

/// What is learned, switchable from the first screen. Each side is written in
/// the language of the person who would pick it, so a learner who reads no
/// Chinese still finds "Learn Chinese". The filled side is the current one.
struct StudyModeSwitch: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            option(.english, title: "學英文")
            option(.chinese, title: "Learn Chinese")
        }
        .padding(2)
        .background(Palette.fill, in: Capsule())
        .fixedSize()
    }

    private func option(_ mode: StudyMode, title: String) -> some View {
        let selected = model.studyMode == mode
        return Button {
            // The whole interface changes language; fade rather than jump.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { model.setStudyMode(mode) }
        } label: {
            Text(title)
                .font(.rounded(.subheadline, weight: .bold))
                .lineLimit(1)
                .foregroundStyle(selected ? .white : Palette.secondaryLabel)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Palette.accent : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("today-mode-\(mode.rawValue)")
    }
}
