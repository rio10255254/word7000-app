import ImageIO
import CoreImage
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
    /// Preserve Vision's highest-confidence spelling, including words and
    /// inflections absent from the built-in vocabulary.
    static func candidates(in images: [UIImage], suggester: WordSuggester?) async throws -> [ScannedWordCandidate] {
        var indices: [String: [Int]] = [:]
        var result: [ScannedWordCandidate] = []
        for (page, image) in images.enumerated() {
            try Task.checkCancellation()
            let prepared = try await preparedImage(image)
            let reading = try await recognize(prepared, languages: languages, suggester: suggester)
            let rows = ScanParser.readingRows(reading.lines)
            let table = await SmartScan.tableCandidates(in: UIImage(cgImage: prepared))
            try Task.checkCancellation()
            var found = ScanGrounding.merging(primary: ScanParser.parse(rows) + ScanParser.parse(reading.lines), supplemental: table)
            let expected = reading.lines.filter { $0.text.unicodeScalars.contains(where: ScanParserContains.cjk) }.count
            let unique = found.count
            let needsHelp = unique == 0 || (expected > 0 && Double(unique) < Double(expected) * 0.7)
            if needsHelp || reading.confidence < 0.7 {
                if let enhanced = await enhancedImage(prepared),
                   let alternate = try? await recognize(enhanced, languages: ["en-US", "zh-Hant"], suggester: suggester) {
                    found = ScanGrounding.merging(primary: found, supplemental: ScanParser.parse(ScanParser.readingRows(alternate.lines)) + ScanParser.parse(alternate.lines))
                }
            }
            try Task.checkCancellation()
            let recovered = found.count
            let assistanceAllowed = await SmartScan.canOrganize
            if (recovered == 0 || Double(recovered) < Double(expected) * 0.7), assistanceAllowed {
                found = ScanGrounding.merging(primary: found, supplemental: await SmartScan.organize(text: rows.map(\.text).joined(separator: "\n")))
            }
            try Task.checkCancellation()
            for candidate in found {
                let key = ScanImportPlan.wordKey(candidate.word)
                var copy = candidate
                copy.key = "p\(page)-\(candidate.key)"
                if !(indices[key] ?? []).contains(where: { ScanImportPlan.sameEntry(result[$0].reviewedWord, candidate.reviewedWord) }) {
                    indices[key, default: []].append(result.count)
                    result.append(copy)
                }
            }
        }
        return result
    }

    static func lines(in image: UIImage, suggester: WordSuggester? = nil) async throws -> [ScannedLine] {
        let prepared = try await preparedImage(image)
        return try await recognize(prepared, languages: languages, suggester: suggester).lines
    }

    private struct Reading: Sendable {
        var lines: [ScannedLine]
        var confidence: Double
    }

    private static func recognize(_ cgImage: CGImage, languages: [String], suggester: WordSuggester?) async throws -> Reading {
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Correction helps sentences but rewrites single headwords and short
            // Chinese meanings into "likelier" words, which is wrong for a word list.
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.004
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            let requested = languages.filter { supported.contains($0) }
            if !requested.isEmpty { request.recognitionLanguages = requested }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            let lines = observations.compactMap { observation -> ScannedLine? in
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
            let confidence = observations.isEmpty ? 0 : observations.reduce(0) { $0 + Double($1.topCandidates(1).first?.confidence ?? 0) } / Double(observations.count)
            return Reading(lines: lines, confidence: confidence)
        }.value
    }

    private static func preparedImage(_ image: UIImage) async throws -> CGImage {
        try await Task.detached(priority: .userInitiated) {
            if let cgImage = image.cgImage, image.imageOrientation == .up,
               max(cgImage.width, cgImage.height) <= ScanPhotoLoader.maximumPixelDimension { return cgImage }
            let pixels = image.cgImage.map { max($0.width, $0.height) } ?? Int(max(image.size.width, image.size.height) * image.scale)
            guard pixels > 0, image.size.width > 0, image.size.height > 0 else { throw Failure.unreadableImage }
            let factor = CGFloat(min(1, Double(ScanPhotoLoader.maximumPixelDimension) / Double(pixels)))
            let size = CGSize(width: image.size.width * image.scale * factor, height: image.size.height * image.scale * factor)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let result = rendered.cgImage else { throw Failure.unreadableImage }
            return result
        }.value
    }

    private static func enhancedImage(_ image: CGImage) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            let adjusted = CIImage(cgImage: image)
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.18])
                .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.3])
            return CIContext(options: [.cacheIntermediates: false]).createCGImage(adjusted, from: adjusted.extent)
        }.value
    }
}

private enum ScanParserContains {
    static func cjk(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x4DBF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value) || (0xF900...0xFAFF).contains(scalar.value)
    }
}
