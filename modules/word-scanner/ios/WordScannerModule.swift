import ExpoModulesCore
import ImageIO
import UIKit
import Vision

// Reads every line of text in a photo, on the device, with Apple Vision.
// Nothing leaves the phone. Boxes are normalised to the image with the origin
// at the top left, which is what the JavaScript parser expects.
public class WordScannerModule: Module {
  public func definition() -> ModuleDefinition {
    Name("WordScanner")

    AsyncFunction("recognizeTextAsync") { (uri: URL, languages: [String]) throws -> [[String: Any]] in
      guard
        let data = try? Data(contentsOf: uri),
        let image = UIImage(data: data),
        let cgImage = image.cgImage
      else {
        throw Exception(name: "ERR_WORD_SCANNER_IMAGE", description: "The photo could not be read.")
      }

      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      // Correction helps sentences but rewrites single headwords and short
      // Chinese meanings into "likelier" words, which is wrong for a word list.
      request.usesLanguageCorrection = false
      let supported = (try? request.supportedRecognitionLanguages()) ?? []
      let requested = languages.filter { supported.contains($0) }
      if !requested.isEmpty {
        request.recognitionLanguages = requested
      }

      let handler = VNImageRequestHandler(
        cgImage: cgImage,
        orientation: CGImagePropertyOrientation(image.imageOrientation),
        options: [:]
      )
      do {
        try handler.perform([request])
      } catch {
        throw Exception(name: "ERR_WORD_SCANNER_RECOGNIZE", description: error.localizedDescription)
      }

      let observations = request.results ?? []
      return observations.compactMap { observation -> [String: Any]? in
        guard let candidate = observation.topCandidates(1).first else {
          return nil
        }
        let box = observation.boundingBox
        return [
          "confidence": Double(candidate.confidence),
          "height": Double(box.height),
          "text": candidate.string,
          "width": Double(box.width),
          "x": Double(box.minX),
          "y": Double(1 - box.maxY),
        ]
      }
    }
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
