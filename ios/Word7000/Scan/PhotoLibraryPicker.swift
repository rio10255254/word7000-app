import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system picker grants access only to the photo the learner selects.
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onSelection: ([NSItemProvider]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        picker.view.accessibilityIdentifier = "scan-photo-library"
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSelection: onSelection) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelection: ([NSItemProvider]) -> Void
        init(onSelection: @escaping ([NSItemProvider]) -> Void) { self.onSelection = onSelection }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            onSelection(results.map(\.itemProvider))
        }
    }
}

enum ScanPhotoLoader {
    enum Failure: Error { case unavailable, unsupportedImage }
    static let maximumPixelDimension = 4096

    /// Decode the provider's temporary file inside its callback, before it is
    /// removed. ImageIO also handles HEIC, iCloud downloads and EXIF rotation.
    static func image(from provider: NSItemProvider) async throws -> UIImage {
        try Task.checkCancellation()
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { throw Failure.unsupportedImage }
        let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true } ?? UTType.image.identifier
        let image: UIImage = try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                guard let url else { continuation.resume(throwing: error ?? Failure.unavailable); return }
                do {
                    continuation.resume(returning: try decode(url: url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        try Task.checkCancellation()
        return image
    }

    static func decode(url: URL) throws -> UIImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
                kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary)
        else { throw Failure.unsupportedImage }
        return UIImage(cgImage: image)
    }
}
