import Foundation
import Testing
@testable import VaaniCore

@MainActor
@Test func unifiedIsSelectableWithoutRemovingThePreviousModelsOrChangingCleanup() throws {
    let unified = try #require(SpeechModel.catalog.first { $0.id == "parakeet-unified" })
    #expect(unified.languages == ["en"])
    #expect(unified.makeProvider() is ParakeetProvider)
    #expect(SpeechModel.catalog.contains { $0.id == "parakeet-v3" })
    #expect(SpeechModel.catalog.contains { $0.id == "parakeet-ultra" })
    #expect(AppSettings().cleanup == .light)
}

@MainActor
@Test func unifiedMissingAssetsFailLocallyWithoutCreatingADownloadDirectory() async throws {
    let model = try #require(SpeechModel.catalog.first { $0.id == "parakeet-unified" })
    let root = FileManager.default.temporaryDirectory.appending(path: "vaani-unified-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let provider = ParakeetProvider(modelsDirectory: root)
    #expect(!ParakeetProvider.isInstalled(model, modelsDirectory: root))
    do {
        try await provider.prepare(model: model, download: false)
        Issue.record("Missing Unified assets must fail without downloading")
    } catch SpeechError.modelNotInstalled {
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
}

@MainActor
@Test func unifiedInstallMarkerDoesNotAcceptIncompleteBundles() throws {
    let model = try #require(SpeechModel.catalog.first { $0.id == "parakeet-unified" })
    let root = FileManager.default.temporaryDirectory.appending(path: "vaani-unified-partial-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = ParakeetProvider.folder(for: model, modelsDirectory: root)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(model.modelName.utf8).write(to: folder.appending(path: ".betterwispr-installed"))
    try FileManager.default.createDirectory(at: folder.appending(path: "parakeet_unified_encoder_int8.mlmodelc"), withIntermediateDirectories: true)
    #expect(!ParakeetProvider.isInstalled(model, modelsDirectory: root))
}
