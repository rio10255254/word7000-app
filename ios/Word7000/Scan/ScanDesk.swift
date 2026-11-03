import SwiftUI
import UIKit
import Word7000Core

// The scanner's first screen as things on a desk: a page under a scanner,
// a little pile of photos, and a ruled notepad to write words on by hand.

/// One of the ways in, drawn as the object it stands for.
struct ScanToolCard<Art: View>: View {
    @Environment(\.appStyle) private var appStyle
    var title: String
    var subtitle: String
    var paper: PaperKind
    var tilt: Double
    var identifier: String
    var action: () -> Void
    @ViewBuilder var art: Art

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                art
                    .frame(height: 104)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                VStack(spacing: 2) {
                    Text(title)
                        .font(.display(.headline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { surface }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 4, seed: Int(tilt * 10) + 7))
                .rotationEffect(.degrees(tilt))
        } else {
            PremiumSurface(radius: 24)
        }
    }
}

/// A page with a word list on it, inside the scanner's corner marks, and a
/// line of light passing down it now and then.
struct ScannerArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        ZStack {
            WordListSheet()
                .frame(width: 70, height: 90)
                .rotationEffect(.degrees(-3))
            CornerMarks()
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 96, height: 104)
            if !reduceMotion {
                LinearGradient(colors: [Palette.accent.opacity(0), Palette.accent.opacity(0.55), Palette.accent.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 84, height: 3)
                    .shadow(color: Palette.accent.opacity(0.6), radius: 4)
                    .offset(y: sweep ? 40 : -40)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.3)) { sweep = true }
                    }
            }
        }
    }
}

/// A few photos of word lists, one on top of the other, the top one taped.
struct PhotoPileArt: View {
    var body: some View {
        ZStack {
            Polaroid(tint: Palette.known.opacity(0.35))
                .rotationEffect(.degrees(-10))
                .offset(x: -16, y: 4)
            Polaroid(tint: Palette.chinese.opacity(0.3))
                .rotationEffect(.degrees(4))
                .offset(x: 6, y: -2)
            Polaroid(tint: nil)
                .rotationEffect(.degrees(9))
                .offset(x: 20, y: 6)
                .overlay(alignment: .top) {
                    TapeStrip(width: 34, angle: -8)
                        .scaleEffect(0.8)
                        .offset(x: 18, y: -6)
                }
        }
    }
}

/// A small photo with a white border; with no tint it shows a word list.
private struct Polaroid: View {
    var tint: Color?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let tint {
                    tint
                } else {
                    WordListSheet(compact: true)
                }
            }
            .frame(width: 54, height: 50)
            .clipped()
            // The wider strip at the bottom of the print; a fixed width, as
            // a bare Color.clear would take the whole row.
            Color.clear.frame(width: 54, height: 12)
        }
        .padding(4)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
    }
}

/// Ivory paper with a few rows of "word — meaning" in strokes.
private struct WordListSheet: View {
    var compact = false

    var body: some View {
        let rows = compact ? 4 : 6
        PaperSurface(kind: .ivory)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: compact ? 6 : 7) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 5) {
                            Capsule().fill(Collage.ink.opacity(0.7)).frame(width: CGFloat([22, 16, 26, 18, 24, 14][row % 6]), height: 3)
                            Capsule().fill(Palette.accent.opacity(0.65)).frame(width: CGFloat([14, 20, 12, 18, 10, 16][row % 6]), height: 3)
                        }
                    }
                }
                .padding(compact ? 6 : 9)
            }
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

/// The four corner marks of a document scanner's frame.
private struct CornerMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.2
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
        }
        return path
    }
}

// MARK: The notepad

/// What the notepad offers for a line that has only the English word or only
/// the Chinese meaning: the rest of the entry, from the word list or the AI.
struct NoteSuggestion: Equatable, Identifiable {
    var id: String { line }
    /// The line as written, trimmed.
    let line: String
    let word: String
    let partOfSpeech: String
    let meaning: String
    let fromAI: Bool

    /// The line as the scanner reads it: "abandon v. 放棄".
    var entry: String { [word, partOfSpeech, meaning].filter { !$0.isEmpty }.joined(separator: " ") }
}

/// Fills in the notepad as the learner writes: each line with only an English
/// word or only a Chinese meaning gets the rest, from the built-in word list at
/// once, or (when the online AI is allowed) from the AI after a short pause.
@MainActor @Observable
final class NotepadHelper {
    private(set) var suggestions: [NoteSuggestion] = []
    /// Lines the AI is looking up now.
    private(set) var asking: [String] = []
    /// Lines nothing local matched, that the AI could look up.
    private(set) var unmatched: [String] = []

    @ObservationIgnored private var byWord: [String: WordEntry] = [:]
    @ObservationIgnored private var byMeaning: [String: WordEntry] = [:]
    @ObservationIgnored private var answers: [String: NoteSuggestion?] = [:]
    @ObservationIgnored private var task: Task<Void, Never>?
    /// The AI is asked about at most this many lines per visit.
    @ObservationIgnored private var asked = 0
    static let maxAsked = 40

    func prepare(words: [WordEntry]) {
        guard byWord.isEmpty else { return }
        var byWord: [String: WordEntry] = [:]
        var byMeaning: [String: WordEntry] = [:]
        var extra: [String: WordEntry] = [:]
        for word in words {
            let key = word.word.lowercased()
            if byWord[key] == nil { byWord[key] = word }
            for part in Self.meaningParts(ChineseDisplay.conciseMeaning(word.meaningZh)) where byMeaning[part] == nil {
                byMeaning[part] = word
            }
            for part in Self.meaningParts(word.meaningZh) + Self.meaningParts(word.supplementalMeaningZh ?? "") where extra[part] == nil {
                extra[part] = word
            }
        }
        self.byWord = byWord
        self.byMeaning = byMeaning.merging(extra) { first, _ in first }
    }

    enum LineKind { case english, chinese }

    /// A line holding only an English word or phrase, or only Chinese.
    static func kind(of line: String) -> LineKind? {
        let scalars = line.unicodeScalars
        let hasHan = scalars.contains { $0.properties.isIdeographic }
        let hasLatin = scalars.contains { $0.isASCII && $0.properties.isAlphabetic }
        if hasHan, !hasLatin { return line.count <= 20 ? .chinese : nil }
        if hasLatin, !hasHan {
            let words = line.split(separator: " ")
            guard (1...4).contains(words.count), line.count <= 40,
                  line.allSatisfy({ $0.isLetter || $0 == " " || $0 == "-" || $0 == "'" || $0 == "’" }) else { return nil }
            return .english
        }
        return nil
    }

    static func incompleteLines(in text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && kind(of: $0) != nil && seen.insert($0).inserted }
    }

    /// The text with every line that has a suggestion written out in full.
    func completed(_ text: String) -> String {
        let byLine = Dictionary(suggestions.map { ($0.line, $0.entry) }, uniquingKeysWith: { first, _ in first })
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            byLine[line.trimmingCharacters(in: .whitespaces)] ?? String(line)
        }.joined(separator: "\n")
    }

    /// `text` with `suggestion`'s line written out in full.
    static func apply(_ suggestion: NoteSuggestion, to text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == suggestion.line }) {
            lines[index] = suggestion.entry
        }
        return lines.joined(separator: "\n")
    }

    func update(text: String, aiAllowed: Bool) {
        task?.cancel()
        let lines = Self.incompleteLines(in: text).prefix(30)
        var found: [NoteSuggestion] = []
        var missing: [String] = []
        for line in lines {
            if let local = local(line) {
                found.append(local)
            } else if let answer = answers[line] {
                if let answer { found.append(answer) }
            } else {
                missing.append(line)
            }
        }
        suggestions = found
        unmatched = missing
        asking = []
        guard aiAllowed, !missing.isEmpty, asked < Self.maxAsked else { return }
        // The line being typed is still changing: wait for a pause.
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await self?.ask(missing)
        }
    }

    private func ask(_ lines: [String]) async {
        for line in lines.prefix(6) {
            guard !Task.isCancelled, asked < Self.maxAsked, CloudAssistant.shared.ready else { return }
            if let usage = CloudAssistant.shared.usage, usage.remaining < 4 { return }
            asked += 1
            asking.append(line)
            var reply: CloudAI.WordSuggestion?
            do {
                let answer: CloudAI.WordSuggestion = try await CloudAssistant.shared.run(
                    .fillWord, ["word": .string(String(line.prefix(80)))], as: CloudAI.WordSuggestion.self)
                reply = answer.cleaned()
            } catch {
                reply = nil
            }
            asking.removeAll { $0 == line }
            if Task.isCancelled, reply == nil { return }
            var found: NoteSuggestion?
            if let reply { found = suggestion(for: line, from: reply) }
            answers[line] = found
            unmatched.removeAll { $0 == line }
            if let found, !suggestions.contains(where: { $0.line == line }) {
                suggestions.append(found)
            }
        }
    }

    private func suggestion(for line: String, from reply: CloudAI.WordSuggestion) -> NoteSuggestion? {
        let meaning = ChineseDisplay.conciseMeaning(reply.meaning)
        guard !meaning.isEmpty else { return nil }
        let pos = Self.posLabel(reply.partOfSpeech)
        switch Self.kind(of: line) {
        case .english:
            return NoteSuggestion(line: line, word: line, partOfSpeech: pos, meaning: meaning, fromAI: true)
        case .chinese:
            let word = (reply.word ?? "").trimmingCharacters(in: .whitespaces)
            guard Self.kind(of: word) == .english else { return nil }
            return NoteSuggestion(line: line, word: word, partOfSpeech: pos, meaning: line, fromAI: true)
        case nil:
            return nil
        }
    }

    private func local(_ line: String) -> NoteSuggestion? {
        switch Self.kind(of: line) {
        case .english:
            guard let entry = byWord[line.lowercased()] else { return nil }
            return NoteSuggestion(line: line, word: line, partOfSpeech: Self.posLabel(entry.partOfSpeech),
                                  meaning: ChineseDisplay.conciseMeaning(entry.meaningZh), fromAI: false)
        case .chinese:
            guard let entry = byMeaning[line] else { return nil }
            return NoteSuggestion(line: line, word: entry.word, partOfSpeech: Self.posLabel(entry.partOfSpeech),
                                  meaning: line, fromAI: false)
        case nil:
            return nil
        }
    }

    /// "n / vt / vi" or "adj." as the scanner reads parts of speech: "n./vt./vi.".
    static func posLabel(_ raw: String) -> String {
        let parts = raw.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .map { $0 == "a" ? "adj" : $0 }
            .filter { ScanParser.posTokens.contains($0) }
        var seen = Set<String>()
        return parts.filter { seen.insert($0).inserted }.map { "\($0)." }.joined(separator: "/")
    }

    private static func meaningParts(_ meaning: String) -> [String] {
        meaning.split(whereSeparator: { "；;，,、/（）()".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count <= 12 }
    }
}

/// Lines ruled across the notepad at the text's line height, with the red
/// margin down the left.
private struct NotepadRules: View {
    var spacing: CGFloat
    var top: CGFloat
    var margin: CGFloat

    var body: some View {
        Canvas { context, size in
            var rules = Path()
            var y = top
            while y <= size.height {
                rules.move(to: CGPoint(x: 0, y: y))
                rules.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(rules, with: .color(Collage.ruleLine), lineWidth: 0.8)
            var line = Path()
            line.move(to: CGPoint(x: margin, y: 0))
            line.addLine(to: CGPoint(x: margin, y: size.height))
            context.stroke(line, with: .color(Collage.margin), lineWidth: 1.2)
        }
    }
}

/// A ruled notepad with a glued top: write a word, its meaning, or both on
/// each line, and the cat offers the rest under it.
struct ScanNotepad: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var text: String
    var askCloud: () -> Void
    var read: (String) -> Void
    @State private var helper = NotepadHelper()
    @FocusState private var focused: Bool

    private static let lineGap: CGFloat = 8
    private var lineHeight: CGFloat { UIFont.preferredFont(forTextStyle: .body).lineHeight + Self.lineGap }
    private var aiAllowed: Bool { CloudAssistant.shared.ready }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .topLeading) {
                NotepadRules(spacing: lineHeight, top: 14 + lineHeight - 4, margin: 34)
                    .accessibilityHidden(true)
                if text.isEmpty {
                    Text(S.notepadPlaceholder)
                        .font(.body)
                        .lineSpacing(Self.lineGap)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 44)
                        .padding(.top, 14)
                        .padding(.trailing, 14)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextField("", text: $text, axis: .vertical)
                    .font(.body)
                    .lineSpacing(Self.lineGap)
                    .lineLimit(5...14)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.leading, 44)
                    .padding(.top, 14)
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
                    .accessibilityLabel(S.notepadTitle)
                    .accessibilityHint(S.notepadPlaceholder)
                    .accessibilityIdentifier("scan-pasted-text")
            }
            .background { PaperSurface(kind: .ivory) }
            suggestionsList
            footer
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .background {
            // The pages underneath, a little askew.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(PaperKind.ivory.color)
                .rotationEffect(.degrees(1.6))
                .offset(y: 4)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        .onAppear {
            helper.prepare(words: model.vocabularyWords)
            helper.update(text: text, aiAllowed: aiAllowed)
        }
        .onChange(of: text) { _, new in helper.update(text: new, aiAllowed: aiAllowed) }
        .onChange(of: aiAllowed) { _, allowed in helper.update(text: text, aiAllowed: allowed) }
        .animation(reduceMotion ? nil : Motion.reveal, value: helper.suggestions)
        .animation(reduceMotion ? nil : Motion.reveal, value: helper.asking)
    }

    /// The pad's glued top, in leather, with paste on the right.
    private var header: some View {
        HStack(spacing: 10) {
            Label(S.notepadTitle, systemImage: "pencil.and.list.clipboard")
                .font(.display(.subheadline, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Button {
                if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                    text = text.isEmpty ? pasted : text + (text.hasSuffix("\n") ? "" : "\n") + pasted
                }
            } label: {
                Label(S.paste, systemImage: "doc.on.clipboard")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.22), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier("scan-paste")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            LinearGradient(colors: [Color(red: 0.77, green: 0.55, blue: 0.36), Color(red: 0.55, green: 0.35, blue: 0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay { PaperGrain(opacity: 1).blendMode(.overlay) }
        }
    }

    /// The cat's suggestions for lines written half-way, each one to tap in.
    @ViewBuilder
    private var suggestionsList: some View {
        let waiting = helper.unmatched.filter { !helper.asking.contains($0) }
        if !helper.suggestions.isEmpty || !helper.asking.isEmpty || (!waiting.isEmpty && CloudAssistant.shared.needsConsent) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(S.catSuggests, systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                    Spacer()
                    if helper.suggestions.count > 1 {
                        Button(S.fillAll) {
                            withAnimation(reduceMotion ? nil : Motion.reveal) { text = helper.completed(text) }
                        }
                        .font(.caption.weight(.bold))
                        .accessibilityIdentifier("scan-note-fill-all")
                    }
                }
                ForEach(helper.suggestions) { suggestion in
                    Button {
                        withAnimation(reduceMotion ? nil : Motion.reveal) { text = NotepadHelper.apply(suggestion, to: text) }
                    } label: {
                        HStack(spacing: 8) {
                            Text(suggestion.line)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                            HStack(spacing: 6) {
                                Text(suggestion.word).fontWeight(.semibold).foregroundStyle(Palette.ink)
                                if !suggestion.partOfSpeech.isEmpty {
                                    Text(suggestion.partOfSpeech).foregroundStyle(Palette.chinese)
                                }
                                Text(suggestion.meaning).foregroundStyle(Palette.ink)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            Spacer(minLength: 4)
                            if suggestion.fromAI {
                                Image(systemName: "sparkles").font(.caption2).foregroundStyle(Palette.accent)
                                    .accessibilityLabel("AI")
                            }
                            Image(systemName: "plus.circle.fill").foregroundStyle(Palette.accent)
                        }
                        .font(.subheadline)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel(S.fillLine(suggestion.line, suggestion.entry))
                    .accessibilityIdentifier("scan-note-suggestion")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ForEach(helper.asking, id: \.self) { line in
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.mini)
                        Text(S.lookingUp(line)).lineLimit(1)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                }
                if !waiting.isEmpty, CloudAssistant.shared.needsConsent {
                    Button(action: askCloud) {
                        Label(S.letAIFill, systemImage: "sparkles").font(.footnote.weight(.semibold))
                    }
                    .accessibilityIdentifier("scan-note-ask-ai")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { PaperSurface(kind: .peach).opacity(0.55) }
            .overlay(alignment: .top) {
                Rectangle().fill(Collage.ink.opacity(0.08)).frame(height: 1)
            }
        }
    }

    private var footer: some View {
        Button {
            focused = false
            read(helper.completed(text))
        } label: {
            Label(S.readPasted, systemImage: "list.bullet.rectangle.portrait")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .prominentAction()
        .disabled(text.trimmed.isEmpty)
        .accessibilityIdentifier("scan-read-pasted")
        .padding(12)
        .background { PaperSurface(kind: .ivory) }
    }
}

private enum S {
    static var notepadTitle: String { L.t("自己寫", "Write it yourself") }
    static var notepadPlaceholder: String {
        L.t("一行一個字，英文、中文或兩個都寫\nabandon\n好處\nbenefit n. 好處", "One word a line: English, Chinese or both\nabandon\n好處\nbenefit n. 好處")
    }
    static var paste: String { L.t("貼上", "Paste") }
    static var catSuggests: String { L.t("小笨貓幫你補", "Silly Cat fills in") }
    static var fillAll: String { L.t("全部補上", "Fill all") }
    static func fillLine(_ line: String, _ entry: String) -> String { L.t("把「\(line)」補成 \(entry)", "Fill in \u{201C}\(line)\u{201D} as \(entry)") }
    static func lookingUp(_ line: String) -> String { L.t("正在查「\(line)」…", "Looking up \u{201C}\(line)\u{201D}…") }
    static var letAIFill: String { L.t("讓 AI 補上沒查到的字", "Let the AI fill in the rest") }
    static var readPasted: String { L.t("整理成單字表", "Make it a word list") }
}
