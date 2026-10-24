import AVFAudio
import CryptoKit
import Foundation

public struct DictationEvidence: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID { transcript.id }
    public var transcript: Transcript
    public var modelID: String
    public var settingsJSON: Data
    public var vocabulary: [VocabularyEntry]
    public var recognition: RecognitionDetails?
    public var failure: String?
    public var appVersion: String
    public var pinned = false
    public var referenceText: String?
    public var reviewedAt: Date?
    public var sha256 = ""
    public var sampleRate = 0.0
    public var channels: UInt32 = 0
    public var audioBytes: Int64 = 0
    public var audioFilename = "audio.caf"
    public var timings: [String: Double]

    public init(transcript: Transcript, modelID: String, settingsJSON: Data, vocabulary: [VocabularyEntry],
                recognition: RecognitionDetails? = nil, failure: String? = nil, appVersion: String = "unknown",
                timings: [String: Double] = [:]) {
        self.transcript = transcript
        self.modelID = modelID
        self.settingsJSON = settingsJSON
        self.vocabulary = vocabulary
        self.recognition = recognition
        self.failure = failure
        self.appVersion = appVersion
        self.timings = timings
    }
}

/// Owns private, lossless audio and its immutable recognition stages off the UI actor.
public actor DictationEvidenceStore {
    public static let recentLimit = 50
    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "BetterWispr/DictationEvidence", directoryHint: .isDirectory)
    }
    public let directory: URL
    private let files = FileManager.default
    private var deletedIDs: Set<UUID> = []
    private var clearedThrough: Date?

    public init(directory: URL = DictationEvidenceStore.defaultDirectory) { self.directory = directory }

    public func records() throws -> [DictationEvidence] {
        guard files.fileExists(atPath: directory.path) else { return [] }
        let folders = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        // The actor never suspends during save, so pending bundles here belong to an interrupted process.
        for folder in folders where folder.lastPathComponent.hasPrefix(".") && folder.lastPathComponent.hasSuffix("-pending") {
            let name = String(folder.lastPathComponent.dropFirst().dropLast("-pending".count))
            if UUID(uuidString: name) != nil { try files.removeItem(at: folder) }
        }
        return try folders.filter { UUID(uuidString: $0.lastPathComponent) != nil }
            .map { folder in
                let record = try JSONDecoder().decode(DictationEvidence.self, from: Data(contentsOf: folder.appending(path: "record.json")))
                guard folder.lastPathComponent == record.id.uuidString, record.audioFilename == "audio.caf" else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                return record
            }
            .sorted { $0.transcript.createdAt > $1.transcript.createdAt }
    }

    public func save(audioURL: URL, record: DictationEvidence) throws {
        try Task.checkCancellation()
        guard !deletedIDs.contains(record.id), clearedThrough.map({ record.transcript.createdAt > $0 }) ?? true else { return }
        // Refuse to evict anything when existing metadata cannot be read.
        _ = try records()
        try files.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destination = folder(record.id)
        guard !files.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
        let staging = directory.appending(path: ".\(record.id.uuidString)-pending", directoryHint: .isDirectory)
        try files.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? files.removeItem(at: staging) }
        let output = staging.appending(path: "audio.caf")
        try files.copyItem(at: audioURL, to: output)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
        let audio = try AVAudioFile(forReading: output)
        guard audio.length > 0 else { throw CocoaError(.fileReadCorruptFile) }
        var record = record
        record.sampleRate = audio.fileFormat.sampleRate
        record.channels = audio.fileFormat.channelCount
        record.audioBytes = (try files.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.int64Value ?? 0
        let input = try FileHandle(forReadingFrom: output)
        defer { try? input.close() }
        var hash = SHA256()
        while let bytes = try input.read(upToCount: 1_048_576), !bytes.isEmpty {
            try Task.checkCancellation()
            hash.update(data: bytes)
        }
        record.sha256 = hash.finalize().map { String(format: "%02x", $0) }.joined()
        try write(record, in: staging)
        try Task.checkCancellation()
        try files.moveItem(at: staging, to: destination)
        try prune()
    }

    public func audioURL(id: UUID) throws -> URL {
        let record = try load(id)
        let url = folder(id).appending(path: record.audioFilename)
        guard files.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        return url
    }

    public func setPinned(id: UUID, pinned: Bool) throws {
        var record = try load(id)
        record.pinned = pinned
        try write(record, in: folder(id))
        try prune()
    }

    public func setReference(id: UUID, text: String, reviewed: Bool) throws {
        var record = try load(id)
        record.referenceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        record.reviewedAt = reviewed && !(record.referenceText?.isEmpty ?? true) ? .now : nil
        try write(record, in: folder(id))
    }

    public func delete(id: UUID) throws {
        deletedIDs.insert(id)
        let url = folder(id)
        if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
    }

    public func clear() throws {
        // Validate first so an unreadable record is never silently destroyed.
        let all = try records()
        clearedThrough = .now
        for record in all { try delete(id: record.id) }
    }

    private func folder(_ id: UUID) -> URL { directory.appending(path: id.uuidString, directoryHint: .isDirectory) }
    private func load(_ id: UUID) throws -> DictationEvidence {
        guard let record = try records().first(where: { $0.id == id }) else { throw CocoaError(.fileNoSuchFile) }
        return record
    }
    private func write(_ record: DictationEvidence, in folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = folder.appending(path: "record.json")
        try encoder.encode(record).write(to: url, options: .atomic)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private func prune() throws {
        let expired = try records().filter { !$0.pinned }.dropFirst(Self.recentLimit)
        for record in expired { try delete(id: record.id) }
    }
}
