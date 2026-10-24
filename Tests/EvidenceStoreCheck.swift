import Foundation

@main struct EvidenceStoreCheck {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "evidence-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let audio = root.appending(path: "source.wav")
        var wav = Data("RIFF".utf8)
        func number<T: FixedWidthInteger>(_ value: T) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
        wav += number(UInt32(36 + 320)); wav += Data("WAVEfmt ".utf8); wav += number(UInt32(16))
        wav += number(UInt16(1)); wav += number(UInt16(1)); wav += number(UInt32(16000)); wav += number(UInt32(32000))
        wav += number(UInt16(2)); wav += number(UInt16(16)); wav += Data("data".utf8); wav += number(UInt32(320)); wav += Data(repeating: 0, count: 320)
        try wav.write(to: audio)
        let folder = root.appending(path: "records")
        let store = DictationEvidenceStore(directory: folder)
        func record(_ offset: Int) -> DictationEvidence {
            DictationEvidence(transcript: Transcript(createdAt: Date(timeIntervalSince1970: Double(offset)), text: "Tell me", rawText: "tall me", duration: 0.01, modelName: "test", language: "en"), modelID: "test", settingsJSON: Data("{}".utf8), vocabulary: [], recognition: RecognitionDetails(originalText: "tell me", changes: [.init(original: "tell", replacement: "tall")]))
        }
        let pinned = record(0)
        try await store.save(audioURL: audio, record: pinned)
        try await store.setPinned(id: pinned.id, pinned: true)
        var ids: [UUID] = []
        for i in 1...51 { let item = record(i); ids.append(item.id); try await store.save(audioURL: audio, record: item) }
        let records = try await store.records()
        precondition(records.count == 51, "50 recent plus one pin")
        precondition(!records.contains { $0.id == ids[0] }, "oldest unpinned evicted")
        precondition(records.contains { $0.id == pinned.id && $0.pinned }, "pin survives")
        let reloaded = DictationEvidenceStore(directory: folder)
        let persistent = try await reloaded.records()
        precondition(persistent.count == 51)
        let retained = try await reloaded.audioURL(id: pinned.id)
        let retainedBytes = try Data(contentsOf: retained)
        precondition(retainedBytes == wav, "lossless retention")
        precondition(persistent.first(where: { $0.id == pinned.id })?.recognition?.originalText == "tell me")
        try await reloaded.setReference(id: pinned.id, text: "Tell me", reviewed: true)
        let reviewed = try await reloaded.records().first { $0.id == pinned.id }
        precondition(reviewed?.referenceText == "Tell me" && reviewed?.reviewedAt != nil)
        try await reloaded.setPinned(id: pinned.id, pinned: false)
        let afterUnpin = try await reloaded.records()
        precondition(afterUnpin.count == 50 && !afterUnpin.contains { $0.id == pinned.id })
        let corrupt = folder.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: corrupt, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: corrupt.appending(path: "record.json"))
        do { _ = try await reloaded.records(); preconditionFailure("corruption must be reported") } catch {}
        precondition(FileManager.default.fileExists(atPath: corrupt.path))
        try FileManager.default.removeItem(at: corrupt)
        let duplicate = persistent.first!
        do { try await reloaded.save(audioURL: audio, record: duplicate); preconditionFailure("duplicate overwrite") } catch {}
        let cancelledRecord = record(90)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await reloaded.save(audioURL: audio, record: cancelledRecord)
        }
        do { try await cancelled.value; preconditionFailure("cancelled save accepted") } catch is CancellationError {}
        let afterCancel = try await reloaded.records()
        precondition(afterCancel.count == 50 && !afterCancel.contains { $0.id == cancelledRecord.id })
        let blockedDirectory = root.appending(path: "blocked")
        try Data([0]).write(to: blockedDirectory)
        let blockedStore = DictationEvidenceStore(directory: blockedDirectory)
        do { try await blockedStore.save(audioURL: audio, record: record(95)); preconditionFailure("unwritable directory accepted") } catch {}
        precondition(FileManager.default.fileExists(atPath: audio.path), "source remains owned by caller on failure")
        let deletedBeforeSave = record(96)
        try await reloaded.delete(id: deletedBeforeSave.id)
        try await reloaded.save(audioURL: audio, record: deletedBeforeSave)
        let afterPendingDelete = try await reloaded.records()
        precondition(!afterPendingDelete.contains { $0.id == deletedBeforeSave.id }, "deleted audio must not reappear from pending archival")
        let abandoned = folder.appending(path: ".\(UUID().uuidString)-pending")
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        try wav.write(to: abandoned.appending(path: "audio.caf"))
        _ = try await reloaded.records()
        precondition(!FileManager.default.fileExists(atPath: abandoned.path), "interrupted saves must be reconciled")
        let missing = record(100)
        do { try await reloaded.save(audioURL: root.appending(path: "missing"), record: missing); preconditionFailure("missing source accepted") } catch {}
        let afterMissing = try await reloaded.records()
        precondition(afterMissing.count == 50)
        try await reloaded.delete(id: ids.last!)
        let afterDelete = try await reloaded.records()
        precondition(afterDelete.count == 49)
        try await reloaded.clear()
        try await reloaded.save(audioURL: audio, record: record(120))
        let afterClear = try await reloaded.records()
        precondition(afterClear.isEmpty)
        print("PASS: rolling 50, pins/restart, lossless audio, provenance, reviewed reference, unpin eviction, corruption preservation, missing audio, delete, clear")
    }
}
