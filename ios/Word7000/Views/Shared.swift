import AVFoundation
import SwiftUI
import Word7000Core

/// Reads a word aloud with the system voice; works offline.
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}

struct SpeakButton: View {
    var text: String

    var body: some View {
        Button { Speaker.shared.speak(text) } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.pronounce)
    }
}

/// Status, level, first letter and (in the library) sort order.
struct FilterSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: FilterSelection
    var showsSort: Bool

    private let initials = ["all"] + (65...90).map { String(UnicodeScalar($0)!) }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.filterStatus) {
                    Picker(L.filterStatus, selection: $selection.status) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            Text(L.filterLabel(filter)).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    Picker(L.filterLevel, selection: $selection.level) {
                        Text(L.allLevels).tag("all")
                        ForEach(model.levels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    Picker(L.filterInitial, selection: $selection.initial) {
                        ForEach(initials, id: \.self) { initial in
                            Text(initial == "all" ? L.allInitials : initial).tag(initial)
                        }
                    }
                    if showsSort {
                        Picker(L.filterSort, selection: $selection.sort) {
                            Text(L.sortDefault).tag(LibrarySort.default)
                            Text(L.sortAlphabetical).tag(LibrarySort.alphabetical)
                        }
                    }
                }
                if selection != FilterSelection() {
                    Section {
                        Button(L.resetFilters, role: .destructive) { selection = FilterSelection() }
                    }
                }
            }
            .navigationTitle(L.filters)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.closeSheet) { dismiss() }
                }
            }
        }
    }
}

struct BankPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    bankRow(id: WordBanks.coreBankId, name: L.coreBankName, count: model.vocabularyWords.count, icon: "square.stack.3d.up.fill", tag: L.builtInBank, color: Palette.accent)
                    ForEach(model.customSets.sets) { set in
                        let scanned = set.wordIds.contains(where: WordBanks.isScannedWordId)
                        bankRow(id: set.id, name: set.name, count: WordBanks.words(of: set, in: model.allWords).count, icon: scanned ? "doc.text.viewfinder" : "folder.fill", tag: scanned ? L.scanBankTag : nil, color: Color(hex: set.color) ?? Palette.accent)
                    }
                } footer: {
                    Text(L.bankPickerHint)
                }
            }
            .navigationTitle(L.bankPickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.closeSheet) { dismiss() }
                }
            }
        }
    }

    private func bankRow(id: String, name: String, count: Int, icon: String, tag: String?, color: Color) -> some View {
        Button {
            model.selectBank(id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).foregroundStyle(.primary)
                    Text(L.bankWordCount(count)).font(.caption).foregroundStyle(.secondary)
                }
                if let tag { Tag(text: tag, color: color) }
                Spacer()
                if model.settings.activeBankId == id {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.accent)
                }
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}
