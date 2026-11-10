import Foundation
import Vision
import CoreImage
import ImageIO

func load(_ path: String) -> CGImage {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                 kCGImageSourceThumbnailMaxPixelSize: 4096]
    return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)!
}

func run(_ image: CGImage, _ langs: [String], _ label: String) throws {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.minimumTextHeight = 0.004
    request.recognitionLanguages = langs
    try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
    print("=== \(label) \(langs)")
    for o in request.results ?? [] {
        let b = o.boundingBox
        let reads = o.topCandidates(3).map { "\($0.string)|\(String(format: "%.2f", $0.confidence))" }
        print(String(format: "ScannedLine(text: %@, x: %.4f, y: %.4f, width: %.4f, height: %.4f), // %@",
                     "\"\(o.topCandidates(1).first?.string ?? "")\"", b.minX, 1 - b.maxY, b.width, b.height, reads.joined(separator: " ; ")))
    }
}

let image = load(CommandLine.arguments[1])
print("size \(image.width)x\(image.height)")
try run(image, ["zh-Hant", "en-US"], "primary")
let adjusted = CIImage(cgImage: image)
    .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.18])
    .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.3])
let enhanced = CIContext().createCGImage(adjusted, from: adjusted.extent)!
try run(enhanced, ["en-US", "zh-Hant"], "enhanced")
