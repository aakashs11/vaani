// Vaani addition, 2026. Preserves the BetterWispr workspace during the identity transition.
import CryptoKit
import Foundation

public enum LegacyIdentityMigration {
    private static let receiptName = ".vaani-migration.json"
    private struct Receipt: Codable {
        let version: Int
        let source: String
        let files: [String: String]
    }

    public static func migrate(from source: URL, to destination: URL) throws -> Bool {
        let fm = FileManager.default
        guard source.standardizedFileURL != destination.standardizedFileURL else { throw Failure.conflict }
        guard fm.fileExists(atPath: source.path) else { return false }
        guard try source.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw Failure.invalid }
        if fm.fileExists(atPath: destination.path) {
            guard try destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw Failure.conflict }
        }
        let manifest = try snapshot(source)
        if fm.fileExists(atPath: destination.path) {
            guard let data = try? Data(contentsOf: destination.appendingPathComponent(receiptName)),
                  let receipt = try? JSONDecoder().decode(Receipt.self, from: data),
                  receipt.version == 1, receipt.source == source.standardizedFileURL.path,
                  receipt.files == manifest else { throw Failure.conflict }
            try validate(destination)
            return false
        }
        try validate(source)
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".vaani-migration-\(UUID())")
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: source, to: staging)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: staging.path)
        guard try snapshot(staging) == manifest else { throw Failure.changed }
        try validate(staging)
        let receipt = Receipt(version: 1, source: source.standardizedFileURL.path, files: manifest)
        let url = staging.appendingPathComponent(receiptName)
        try JSONEncoder().encode(receipt).write(to: url, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        // Detect an old process writing during the copy. Never activate a mixed snapshot.
        guard try snapshot(source) == manifest else { throw Failure.changed }
        try fm.moveItem(at: staging, to: destination)
        return true
    }

    private static func validate(_ directory: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.appendingPathComponent("workspace.json").path) else { throw Failure.invalid }
        _ = try LocalStore(directory: directory).load()
        let meetings = MeetingStore(directory: directory.appendingPathComponent("Meetings")).load()
        guard meetings.unreadable.isEmpty else { throw Failure.invalid }
        let evidence = directory.appendingPathComponent("DictationEvidence")
        if fm.fileExists(atPath: evidence.path) {
            for folder in try fm.contentsOfDirectory(at: evidence, includingPropertiesForKeys: nil) where UUID(uuidString: folder.lastPathComponent) != nil {
                let record = try JSONDecoder().decode(DictationEvidence.self, from: Data(contentsOf: folder.appendingPathComponent("record.json")))
                guard record.id.uuidString == folder.lastPathComponent, record.audioFilename == "audio.caf",
                      try digest(folder.appendingPathComponent("audio.caf")) == record.sha256 else { throw Failure.invalid }
            }
        }
    }

    private static func snapshot(_ root: URL) throws -> [String: String] {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        var error: (any Error)?
        guard let items = FileManager.default.enumerator(at: canonicalRoot, includingPropertiesForKeys: keys, errorHandler: { _, failure in
            error = failure
            return false
        }) else { throw Failure.invalid }
        var result: [String: String] = [:]
        for case let url as URL in items {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true else { throw Failure.invalid }
            if values.isRegularFile == true {
                let relative = url.resolvingSymlinksInPath().pathComponents.dropFirst(canonicalRoot.pathComponents.count).joined(separator: "/")
                if relative != receiptName { result[relative] = try digest(url) }
            }
        }
        if let error { throw error }
        return result
    }

    private static func digest(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        while let data = try file.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private enum Failure: LocalizedError {
        case conflict, invalid, changed
        var errorDescription: String? {
            switch self {
            case .conflict: "Both Vaani and BetterWispr data exist without a matching migration record, or the old data changed. Both folders are preserved. Resolve the conflict before reopening Vaani."
            case .invalid: "The saved workspace, meetings, or recordings could not be validated. The original data has been preserved."
            case .changed: "The old app data changed during migration. Close the old app and try again. The original data has been preserved."
            }
        }
    }
}
