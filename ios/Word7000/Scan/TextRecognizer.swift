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

    static func lines(in image: UIImage) async throws -> [ScannedLine] {
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
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let box = observation.boundingBox
                return ScannedLine(
                    text: candidate.string,
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
