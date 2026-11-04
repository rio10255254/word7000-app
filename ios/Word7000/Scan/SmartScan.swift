import ImageIO
import UIKit
import Vision
import Word7000Core

/// The extra readers: Vision's document reader understands tables (iOS 26),
/// and Premium's online AI tidies up handwritten or oddly laid out lists. Both only add pairs whose word and
/// meaning are really on the page (`ScanGrounding`).
enum SmartScan {
    /// Word / meaning pairs from tables Vision finds on the page.
    static func tableCandidates(in image: UIImage) async -> [ScannedWordCandidate] {
        guard #available(iOS 26.0, *) else { return [] }
        guard let cgImage = image.cgImage else { return [] }
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "zh-Hant"), Locale.Language(identifier: "en-US")]
        request.textRecognitionOptions.useLanguageCorrection = false
        guard let documents = try? await request.perform(on: cgImage, orientation: CGImagePropertyOrientation(uiOrientation: image.imageOrientation)) else {
            return []
        }
        var rows: [[String]] = []
        for document in documents {
            for table in document.document.tables {
                for row in table.rows {
                    rows.append(row.map { $0.content.text.transcript })
                }
            }
        }
        return rows.isEmpty ? [] : ScanGrounding.candidates(fromTableRows: rows)
    }

    /// Whether the online AI (Premium) can tidy up the page.
    @MainActor static var canOrganize: Bool {
        IntelligenceSettings.shared.scanAllowed && CloudAssistant.shared.offered
    }

    /// Asks an AI to copy word / meaning pairs out of the recognised text,
    /// then keeps only the pairs that are really on the page.
    @MainActor static func organize(text: String) async -> [ScannedWordCandidate] {
        guard canOrganize else { return [] }
        var chunks: [String] = [], current = ""
        for line in text.prefix(10000).split(separator: "\n", omittingEmptySubsequences: false) {
            if current.count + line.count > 2400, !current.isEmpty {
                chunks.append(current)
                current = current.split(separator: "\n").suffix(2).joined(separator: "\n") + "\n"
            }
            current += line + "\n"
        }
        if !current.isEmpty { chunks.append(current) }
        var found: [ScannedWordCandidate] = []
        for (chunk, source) in chunks.prefix(5).enumerated() {
            guard !Task.isCancelled, canOrganize else { break }
            let entries = await onlineEntries(source)
            guard let entries, !Task.isCancelled, canOrganize else { continue }
            found += entries.enumerated().compactMap { index, entry in
                let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
                let meaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                guard ScanGrounding.isGrounded(word: word, meaning: meaning, in: source) else { return nil }
                return ScannedWordCandidate(key: "ai-\(chunk)-\(index)-\(word.lowercased())", meaningZh: meaning,
                                            partOfSpeech: entry.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines), word: word)
            }
        }
        return found
    }

    @MainActor private static func onlineEntries(_ source: String) async -> [CloudAI.ScanEntries.Entry]? {
        guard CloudAssistant.shared.ready else { return nil }
        return try? await CloudAssistant.shared.run(.scan, ["text": .string(String(source.prefix(4000)))], as: CloudAI.ScanEntries.self).entries
    }
}
