import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// Deterministic test inputs for the real Photos picker and on-device reader.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func drawSheet(width: Int = 2000, height: Int = 1400, columns: Bool = false, faint: Bool = false) -> CGImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSColor(calibratedWhite: faint ? 0.9 : 1, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
    let scale = CGFloat(width) / 2000
    func text(_ value: String, x: CGFloat, top: CGFloat, size: CGFloat = 72) {
        let font = NSFont(name: "PingFangTC-Regular", size: size * scale) ?? NSFont.systemFont(ofSize: size * scale)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(calibratedWhite: faint ? 0.48 : 0.06, alpha: 1)]
        let y = CGFloat(height) - (top + size * 1.4) * scale
        (value as NSString).draw(at: NSPoint(x: x * scale, y: y), withAttributes: attributes)
    }
    text("WORD7000", x: 100, top: 100, size: 84)
    if columns {
        text("objectively adv.", x: 90, top: 450, size: 48)
        text("客觀地", x: 620, top: 450, size: 48)
        text("objective n.", x: 1080, top: 450, size: 48)
        text("目標", x: 1630, top: 450, size: 48)
        text("carefully adv.", x: 90, top: 730, size: 48)
        text("小心地", x: 620, top: 730, size: 48)
    } else {
        text("objectively adv.   客觀地", x: 140, top: 410)
        text("objective n.   目標", x: 140, top: 670)
        text("carefully adv.   小心地", x: 140, top: 930)
    }
    image.unlockFocus()
    var rect = NSRect(origin: .zero, size: image.size)
    return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
}

let context = CIContext(options: [.useSoftwareRenderer: true])
let original = drawSheet()
let sideways = CIImage(cgImage: original).oriented(.left)
let rotated = context.createCGImage(sideways, from: sideways.extent)!
let fixtures: [(String, CGImage, Int, UTType)] = [
    ("01-printed", original, 1, .png),
    ("02-columns", drawSheet(columns: true), 1, .jpeg),
    ("03-faint", drawSheet(faint: true), 1, .jpeg),
    ("04-rotated", rotated, 6, .heic),
    ("05-large", drawSheet(width: 6400, height: 4480), 1, .jpeg),
]
for (index, fixture) in fixtures.enumerated() {
    let url = directory.appendingPathComponent(fixture.0 + "." + fixture.3.preferredFilenameExtension!)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, fixture.3.identifier as CFString, 1, nil)!
    let date = String(format: "2026:10:13 08:00:%02d", index)
    let properties: [CFString: Any] = [
        kCGImagePropertyOrientation: fixture.2,
        kCGImageDestinationLossyCompressionQuality: 0.94,
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: date],
    ]
    CGImageDestinationAddImage(destination, fixture.1, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not create scan fixture") }
    print("Created \(url.lastPathComponent): \(fixture.1.width)x\(fixture.1.height), orientation \(fixture.2)")
}
