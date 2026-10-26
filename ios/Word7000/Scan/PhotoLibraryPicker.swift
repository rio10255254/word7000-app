import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system picker grants access only to the photo the learner selects.
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onSelection: ([NSItemProvider]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
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

    /// The Photos service can drop a transfer without ever calling back; after
    /// this long the learner is told to try again instead of waiting forever.
    static let transferTimeout: TimeInterval = 60

    /// Decode the provider's temporary file inside its callback, before it is
    /// removed. ImageIO also handles HEIC, iCloud downloads and EXIF rotation.
    static func image(from provider: NSItemProvider, timeout: TimeInterval = transferTimeout) async throws -> UIImage {
        try Task.checkCancellation()
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { throw Failure.unsupportedImage }
        let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true } ?? UTType.image.identifier
        let transfer = Transfer()
        let image: UIImage = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard transfer.install(continuation) else { return }
                let progress = provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                    guard let url else { transfer.finish(.failure(error ?? Failure.unavailable)); return }
                    do {
                        transfer.finish(.success(try decode(url: url)))
                    } catch {
                        transfer.finish(.failure(error))
                    }
                }
                transfer.setProgress(progress)
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { transfer.expire() }
            }
        } onCancel: {
            transfer.cancel()
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

    /// A provider may finish after cancellation, so only one path may resume.
    private final class Transfer: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<UIImage, Error>?
        private var progress: Progress?
        private var cancelled = false
        private var finished = false

        func install(_ continuation: CheckedContinuation<UIImage, Error>) -> Bool {
            lock.lock()
            if cancelled {
                lock.unlock()
                continuation.resume(throwing: CancellationError())
                return false
            }
            self.continuation = continuation
            lock.unlock()
            return true
        }

        func setProgress(_ progress: Progress) {
            lock.lock()
            let shouldCancel = cancelled
            if !cancelled && !finished { self.progress = progress }
            lock.unlock()
            if shouldCancel { progress.cancel() }
        }

        func finish(_ result: Result<UIImage, Error>) {
            lock.lock()
            let continuation = continuation
            self.continuation = nil
            progress = nil
            finished = true
            lock.unlock()
            continuation?.resume(with: result)
        }

        /// Gives up on a transfer that never called back; a late callback is ignored.
        func expire() {
            lock.lock()
            guard !finished, let continuation else { lock.unlock(); return }
            let progress = progress
            self.continuation = nil
            self.progress = nil
            finished = true
            lock.unlock()
            progress?.cancel()
            continuation.resume(throwing: Failure.unavailable)
        }

        func cancel() {
            lock.lock()
            cancelled = true
            let continuation = continuation, progress = progress
            self.continuation = nil
            self.progress = nil
            lock.unlock()
            progress?.cancel()
            continuation?.resume(throwing: CancellationError())
        }
    }
}
