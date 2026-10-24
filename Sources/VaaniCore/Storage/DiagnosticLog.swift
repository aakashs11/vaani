// Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
import Foundation
import OSLog

/// Local, bounded metadata only. Speech text remains in the user's existing history.
public actor DiagnosticLog {
    public static let shared = DiagnosticLog(
        directory: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/io.github.aakashs11.vaani"))
    private let directory: URL
    private let maximumBytes: Int

    public init(directory: URL, maximumBytes: Int = 1_048_576) {
        precondition(maximumBytes > 0)
        self.directory = directory
        self.maximumBytes = maximumBytes
    }

    public func record(_ event: String, fields: [String: String] = [:],
                       uptime: TimeInterval = ProcessInfo.processInfo.systemUptime,
                       date: Date = .now) {
        do {
            var row = fields
            row["event"] = event
            row["time"] = ISO8601DateFormatter().string(from: date)
            row["uptime"] = String(uptime)
            let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) + Data([10])
            guard data.count <= maximumBytes else { return }
            let fm = FileManager.default
            try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
            let file = directory.appending(path: "events.jsonl")
            let bytes = (try? fm.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
            if bytes + data.count > maximumBytes {
                let oldest = directory.appending(path: "events.2.jsonl")
                if fm.fileExists(atPath: oldest.path) { try fm.removeItem(at: oldest) }
                let previous = directory.appending(path: "events.1.jsonl")
                if fm.fileExists(atPath: previous.path) { try fm.moveItem(at: previous, to: oldest) }
                if fm.fileExists(atPath: file.path) { try fm.moveItem(at: file, to: previous) }
            }
            if !fm.fileExists(atPath: file.path) {
                guard fm.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Diagnostic failures must never interrupt dictation.
            Logger(subsystem: "io.github.aakashs11.vaani", category: "Diagnostics")
                .error("Diagnostic write failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
