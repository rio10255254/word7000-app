import SwiftUI
import Word7000Core

struct WordNoteView: View {
    @Environment(AppModel.self) private var model
    let note: WordNotes.Note
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.studyMode == .chinese {
                HStack(alignment: .top) {
                    Text(note.translation).accessibilityIdentifier("word-note-chinese-example")
                    Spacer(minLength: 8)
                    SpeakButton(text: note.translation, language: "zh-TW")
                }
                Text(note.example).font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("\(note.word) / \(note.contrast)").font(.headline).foregroundStyle(Palette.accent)
                Text(L.t(note.explanationZh, note.explanationEn))
                Text(note.collocation).font(.subheadline.weight(.semibold))
                HStack(alignment: .top) {
                    Text(note.example)
                    Spacer(minLength: 8)
                    SpeakButton(text: note.example, language: "en-US")
                }
                Text(note.translation).font(.subheadline).foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}
