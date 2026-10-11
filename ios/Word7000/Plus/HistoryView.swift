import SwiftUI
import Word7000Core

/// The long view (Plus): 30 or 90 days of activity, totals, and the words
/// that keep slipping back.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @State private var range = 30

    var body: some View {
        let summary = model.history(days: range)
        let weak = model.weakWords()
        let locked = plus.decide(.history) != .allowed
        List {
            Section {
                Picker(L.t("期間", "Range"), selection: $range) {
                    Text(L.t("30 天", "30 days")).tag(30)
                    Text(L.t("90 天", "90 days")).tag(90)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                WeekBars(days: model.activity(days: range))
                    .frame(height: 140)
                    .padding(.vertical, 8)
            }
            Section {
                HStack(spacing: 0) {
                    StatTile(value: summary.activeDays, label: L.t("學習天數", "Active days"), color: Palette.review)
                    Divider().frame(height: 36)
                    StatTile(value: summary.studied, label: L.t("學習卡", "Cards"), color: Palette.accent)
                    Divider().frame(height: 36)
                    StatTile(value: summary.accuracy ?? 0, label: L.t("答對率 %", "Accuracy %"), color: Palette.known)
                }
                .padding(.vertical, 6)
            }
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
        // Locked: the learner's own history, blurred, under one way to unlock.
        .blur(radius: locked ? 7 : 0)
        .allowsHitTesting(!locked)
        .accessibilityHidden(locked)
        .overlay {
            if locked {
                PlusLockedOverlay(feature: .history)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: locked)
        .navigationTitle(L.t("學習紀錄", "History"))
        .navigationDestination(for: WordEntry.self) { word in WordDetailView(word: word) }
    }
}
