import Foundation
import Testing
@testable import VaaniCore

@Test func diagnosticsRotateAndRemainReadable() async throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let log = DiagnosticLog(directory: folder, maximumBytes: 300)
    for i in 0..<20 {
        await log.record("stage", fields: ["session": "test", "index": String(i)])
    }
    let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    #expect(files.count == 3)
    for file in files {
        let data = try Data(contentsOf: file)
        #expect(data.count <= 300)
        for line in data.split(separator: 10) {
            let row = try #require(JSONSerialization.jsonObject(with: Data(line)) as? [String: String])
            #expect(row["event"] == "stage")
            #expect(row["session"] == "test")
        }
    }
    let active = try String(contentsOf: folder.appending(path: "events.jsonl"), encoding: .utf8)
    #expect(active.contains("\"index\":\"19\""))
}

@Test func diagnosticsFailWithoutThrowingWhenStorageIsUnavailable() async throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try Data([0]).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    await DiagnosticLog(directory: file).record("must_not_interrupt_dictation")
    #expect(try Data(contentsOf: file) == Data([0]))
}
