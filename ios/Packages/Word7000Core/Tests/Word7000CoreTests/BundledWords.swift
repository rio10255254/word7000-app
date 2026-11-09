import Foundation
@testable import Word7000Core

/// The app's built-in word list, read from the repository for the tests
/// that need real words.
enum BundledWords {
    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    static let words: [WordEntry] = {
        let url = repoRoot.appendingPathComponent("ios/Word7000/Resources/words.json")
        return try! WordData.decode(Data(contentsOf: url))
    }()
}
