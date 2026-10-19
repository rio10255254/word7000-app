import Foundation

/// Ordered, atomic writes keep an older background save from replacing newer work.
public final class LearningFileStore: @unchecked Sendable {
    public let directory: URL
    private let queue = DispatchQueue(label: "word7000.local-records", qos: .utility)

    public init(directory: URL) { self.directory = directory }

    public func load<T: Decodable>(_ type: T.Type, from name: String) throws -> T? {
        try queue.sync {
            let url = try file(name)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        }
    }

    public func save<T: Encodable>(_ value: T, to name: String) throws {
        try queue.sync { try write(value, to: name) }
    }

    public func enqueue<T: Encodable & Sendable>(_ value: T, to name: String,
                                                completion: @escaping @Sendable (Bool) -> Void = { _ in }) {
        queue.async {
            do { try self.write(value, to: name); completion(true) }
            catch { completion(false) }
        }
    }

    public func remove(_ name: String) throws {
        try queue.sync {
            let url = try file(name)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    public func finishPendingWrites() { queue.sync {} }

    private func file(_ name: String) throws -> URL {
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return directory.appendingPathComponent(name)
    }

    private func write<T: Encodable>(_ value: T, to name: String) throws {
        let url = try file(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}

/// Retained per account, even after a successful upload or an expired trial.
public struct AccountBackup: Codable, Sendable {
    public var progress: ProgressState?
    public var customSets: CustomSetState?

    public init(progress: ProgressState?, customSets: CustomSetState?) {
        self.progress = progress
        self.customSets = customSets
    }

    public static func fileName(userId: String) -> String {
        let safe = Data(userId.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return "account-\(safe).json"
    }
}
