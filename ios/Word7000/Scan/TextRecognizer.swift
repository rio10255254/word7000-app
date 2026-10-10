import ImageIO
import UIKit
import Vision
import Word7000Core

/// Reads every line of text in a photo on the device with Apple Vision.
/// Nothing leaves the phone. Boxes come back normalised to the image with the
/// origin at the top left, which is what `ScanParser` expects.
enum TextRecognizer {
    static let languages = ["zh-Hant", "en-US"]

    enum Failure: Error {
        case unreadableImage
    }

    /// Reads every page and pairs words with meanings page by page.
    /// Handwriting is often read slightly wrong, so each line keeps Vision's
    /// top three readings and the one that is a dictionary word wins.
    static func candidates(in images: [UIImage], suggester: WordSuggester?) async throws -> [ScannedWordCandidate] {
        var seen = Set<String>()
        var result: [ScannedWordCandidate] = []
        for (page, image) in images.enumerated() {
            let lines = try await lines(in: image, suggester: suggester)
            for candidate in ScanParser.parse(lines) where seen.insert(candidate.word.lowercased()).inserted {
                var copy = candidate
                copy.key = "p\(page)-\(candidate.key)"
                result.append(copy)
            }
        }
        return result
    }

    static func lines(in image: UIImage, suggester: WordSuggester? = nil) async throws -> [ScannedLine] {
        guard let cgImage = image.cgImage else { throw Failure.unreadableImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Correction helps sentences but rewrites single headwords and short
            // Chinese meanings into "likelier" words, which is wrong for a word list.
            request.usesLanguageCorrection = false
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            let requested = languages.filter { supported.contains($0) }
            if !requested.isEmpty { request.recognitionLanguages = requested }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            return (request.results ?? []).compactMap { observation -> ScannedLine? in
                let readings = observation.topCandidates(3).map(\.string)
                guard let text = suggester?.best(of: readings) ?? readings.first else { return nil }
                let box = observation.boundingBox
                return ScannedLine(
                    text: text,
                    x: Double(box.minX),
                    y: Double(1 - box.maxY),
                    width: Double(box.width),
                    height: Double(box.height)
                )
            }
        }.value
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
