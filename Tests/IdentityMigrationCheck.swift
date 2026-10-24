import Foundation
import VaaniCore

func check(_ condition: Bool) { precondition(condition) }

@main struct IdentityMigrationCheck {
    static func main() async throws {
        if CommandLine.arguments.dropFirst().first == "--application-support" {
            print(URL.applicationSupportDirectory.path)
            return
        }
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--migrate" {
            _ = try LegacyIdentityMigration.migrate(from: URL(fileURLWithPath: CommandLine.arguments[2]), to: URL(fileURLWithPath: CommandLine.arguments[3]))
            print("Validated migration completed. Original source retained.")
            return
        }
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("vaani-migration-test-\(UUID())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("BetterWispr")
        let target = root.appendingPathComponent("Vaani")
        check(try LegacyIdentityMigration.migrate(from: source, to: target) == false)
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        var state = SavedState()
        state.settings.shortcut = DictationShortcut(keyCode: 54, modifiers: [], key: "Right Command")!
        state.settings.retainDictationAudio = true
        let original = Transcript(text: "Synthetic example.", rawText: "synthetic example", duration: 1, modelName: "test", language: "en")
        state.history = [original]
        try LocalStore(directory: source).save(state)
        try Data([1,2,3]).write(to: source.appendingPathComponent("cached-model.bin"))
        let audio = root.appendingPathComponent("source.wav")
        var wav = Data("RIFF".utf8)
        func number<T: FixedWidthInteger>(_ value: T) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
        wav += number(UInt32(356)); wav += Data("WAVEfmt ".utf8); wav += number(UInt32(16))
        wav += number(UInt16(1)); wav += number(UInt16(1)); wav += number(UInt32(16000)); wav += number(UInt32(32000))
        wav += number(UInt16(2)); wav += number(UInt16(16)); wav += Data("data".utf8); wav += number(UInt32(320)); wav += Data(repeating: 0, count: 320)
        try wav.write(to: audio)
        let evidenceStore = DictationEvidenceStore(directory: source.appendingPathComponent("DictationEvidence"))
        let evidence = DictationEvidence(transcript: original, modelID: "test", settingsJSON: Data("{}".utf8), vocabulary: [])
        try await evidenceStore.save(audioURL: audio, record: evidence)
        try await evidenceStore.setPinned(id: original.id, pinned: true)
        try await evidenceStore.setReference(id: original.id, text: "Reviewed synthetic example", reviewed: true)
        check(try LegacyIdentityMigration.migrate(from: source, to: target))
        check(try LocalStore(directory: target).load() == state)
        check(try Data(contentsOf: target.appendingPathComponent("cached-model.bin")) == Data([1,2,3]))
        check(fm.fileExists(atPath: source.appendingPathComponent("workspace.json").path))
        let migratedEvidence = DictationEvidenceStore(directory: target.appendingPathComponent("DictationEvidence"))
        let saved = try await migratedEvidence.records()
        check(saved.count == 1 && saved[0].pinned && saved[0].referenceText == "Reviewed synthetic example")
        check(try Data(contentsOf: await migratedEvidence.audioURL(id: original.id)) == wav)
        state.history.append(Transcript(text: "New Vaani text", rawText: "New Vaani text", duration: 2, modelName: "test", language: "en"))
        try LocalStore(directory: target).save(state)
        check(try LegacyIdentityMigration.migrate(from: source, to: target) == false)
        check(try LocalStore(directory: target).load() == state)
        let alias = root.appendingPathComponent("linked-source")
        let linkedTarget = root.appendingPathComponent("linked-result")
        try fm.createSymbolicLink(at: alias, withDestinationURL: source)
        do { _ = try LegacyIdentityMigration.migrate(from: alias, to: linkedTarget); fatalError("Symlink source was copied as a shared workspace") } catch {}
        check(!fm.fileExists(atPath: linkedTarget.path))
        check(!fm.fileExists(atPath: source.appendingPathComponent(".vaani-migration.json").path))
        try Data("changed by old app".utf8).write(to: source.appendingPathComponent("workspace.json"))
        do { _ = try LegacyIdentityMigration.migrate(from: source, to: target); fatalError("Changed legacy source was accepted") } catch {}
        check(try LocalStore(directory: target).load() == state)
        let conflict = root.appendingPathComponent("conflict")
        try LocalStore(directory: conflict).save(state)
        do { _ = try LegacyIdentityMigration.migrate(from: source, to: conflict); fatalError("Unrelated destination was replaced") } catch {}
        check(try LocalStore(directory: conflict).load() == state)
        let corruptTarget = root.appendingPathComponent("corrupt-target")
        do { _ = try LegacyIdentityMigration.migrate(from: source, to: corruptTarget); fatalError("Corrupt source was accepted") } catch {}
        check(!fm.fileExists(atPath: corruptTarget.path))
        let missingAudioSource = root.appendingPathComponent("missing-audio")
        try FileManager.default.copyItem(at: target, to: missingAudioSource)
        let missingAudio = missingAudioSource.appendingPathComponent("DictationEvidence/\(original.id.uuidString)/audio.caf")
        try fm.removeItem(at: missingAudio)
        do { _ = try LegacyIdentityMigration.migrate(from: missingAudioSource, to: root.appendingPathComponent("missing-audio-result")); fatalError("Missing recording was accepted") } catch {}
        let unsupported = root.appendingPathComponent("unsupported")
        var badState = state; badState.version = 999
        try LocalStore(directory: unsupported).save(badState)
        do { _ = try LegacyIdentityMigration.migrate(from: unsupported, to: root.appendingPathComponent("unsupported-result")); fatalError("Unsupported schema was accepted") } catch {}
        let blocked = root.appendingPathComponent("blocked-parent")
        try Data([1]).write(to: blocked)
        do { _ = try LegacyIdentityMigration.migrate(from: target, to: blocked.appendingPathComponent("Vaani")); fatalError("Write failure was ignored") } catch {}
        check(try LocalStore(directory: target).load() == state)
        print("Identity migration checks passed: source preservation, settings/history/model bytes, repeat launch, Vaani edits, divergent source, destination conflict, corrupt source.")
    }
}
