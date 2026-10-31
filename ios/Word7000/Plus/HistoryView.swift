import SwiftUI
import Word7000Core

/// Seven days are free; Plus also unlocks the longer view and weak words.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var range = 7

    var body: some View {
        let locked = range > PlusPolicy.freeHistoryDays && plus.decide(.history) != .allowed
        VStack(spacing: 0) {
            Picker(L.t("期間", "Range"), selection: $range) {
                Text(L.t("7 天", "7 days")).tag(7)
                Text(L.t("30 天", "30 days")).tag(30)
                Text(L.t("90 天", "90 days")).tag(90)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            historyList
                .blur(radius: locked ? 7 : 0)
                .allowsHitTesting(!locked)
                .accessibilityHidden(locked)
                .overlay {
                    if locked {
                        PlusLockedOverlay(feature: .history)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
        }
        .background { AmbientBackground() }
        .animation(.smooth, value: locked)
        .sensoryFeedback(.selection, trigger: range) { _, _ in model.settings.hapticsEnabled ?? true }
        .navigationTitle(L.t("學習紀錄", "History"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: WordEntry.self) { word in WordDetailView(word: word) }
    }

    private var historyList: some View {
        let summary = model.history(days: range)
        let weak = model.weakWords()
        return List {
            Group {
                Section {
                    HistoryActivityChart(activity: model.activity(days: range))
                } header: {
                    Text(L.t("每日學習次數", "Daily learning actions"))
                }
                Section {
                    HStack(spacing: 0) {
                        StatTile(value: summary.activeDays, label: L.t("學習天數", "Active days"), color: Palette.review)
                        Divider().frame(height: 36)
                        StatTile(value: summary.studied, label: L.t("學習卡", "Cards"), color: Palette.accent)
                        Divider().frame(height: 36)
                        StatTile(value: summary.accuracy, label: L.t("答對率 %", "Accuracy %"), color: Palette.known)
                    }
                    .padding(.vertical, 6)
                    // The totals roll to the new range instead of jumping.
                    .animation(reduceMotion ? nil : Motion.reveal, value: range)
                    LabeledContent(L.t("完成口說練習", "Speaking practice completed"),
                                   value: L.t("\(summary.speakingCompleted) 次", "\(summary.speakingCompleted) sessions"))
                }
                if range > PlusPolicy.freeHistoryDays {
                    Section {
                        if weak.isEmpty {
                            Text(L.t("目前沒有反覆卡住的單字。", "No words keep slipping back."))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(weak) { word in
                            NavigationLink(value: word) {
                                WordRow(word: word, progress: model.progress(for: word.id))
                            }
                        }
                    } header: {
                        Text(L.t("弱點單字", "Weak words"))
                    } footer: {
                        Text(L.t("忘記越多次的字排越前面，可以優先複習。", "Words forgotten most often come first."))
                    }
                }
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
    }
}
