import SwiftUI
import Word7000Core

/// Ten short questions to answer out loud, each built around one word.
/// Nothing is recorded; the learner answers, then compares with a sample.
struct SpeakingSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var words: [WordEntry] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var answered = 0

    var body: some View {
        NavigationStack {
            Group {
                if words.isEmpty {
                    ContentUnavailableView(L.noQuizWords, systemImage: "bubble.left.and.text.bubble.right")
                } else if index >= words.count {
                    finished
                } else {
                    prompt(words[index])
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.close)
                }
                ToolbarItem(placement: .principal) {
                    if index < words.count {
                        Text("\(index + 1) / \(words.count)")
                            .font(.rounded(.subheadline, weight: .semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
        .onAppear {
            if words.isEmpty { words = model.quizQuestions(count: 10, seed: SeededRandom.runtimeSeed()) }
        }
    }

    private func prompt(_ word: WordEntry) -> some View {
        let card = ConversationPrompts.build(word, mode: model.studyMode == .english ? .english : .chinese)
        let face = model.face(word)
        return VStack(spacing: 16) {
            SessionBar(fraction: Double(index + (revealed ? 1 : 0)) / Double(max(1, words.count)))
                .padding(.top, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.keyword).font(.roundedSize(30, weight: .bold))
                            if !card.keywordPronunciation.isEmpty {
                                Text(card.keywordPronunciation).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        SpeakButton(text: face.speakText, language: face.speakLanguage)
                    }
                    Text(card.question)
                        .font(.title3.weight(.semibold))
                    Text(card.questionSupport)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if revealed {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.sampleAnswer).font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                            Text(card.referenceAnswer)
                            Text(card.referenceTranslation).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .card(radius: Metrics.wordCardRadius, padding: 20)
            }
            if revealed {
                Button(action: next) {
                    Text(index + 1 >= words.count ? L.seeResults : L.nextQuestion).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
            } else {
                HStack(spacing: 12) {
                    Button { reveal(completed: false) } label: {
                        Text(L.showSample).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    Button { reveal(completed: true) } label: {
                        Text(L.spokeIt).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: Palette.known)
                }
            }
        }
    }

    private func reveal(completed: Bool) {
        model.recordSpeaking(completed: completed)
        if completed { answered += 1 }
        withAnimation(.snappy) { revealed = true }
    }

    private func next() {
        revealed = false
        index += 1
    }

    private var finished: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(Palette.known)
            Text(L.speakingFinished).font(.rounded(.title, weight: .bold))
            Text(L.speakingScore(answered)).foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: {
                Text(L.done).font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
        }
    }
}
