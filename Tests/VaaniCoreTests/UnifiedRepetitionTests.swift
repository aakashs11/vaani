import Testing
@testable import FluidAudio

/// Covers the pinned dependency compatibility patch without loading a model.
@Test func unifiedSingleWindowPreservesCaseChangingRepetition() {
    let config = UnifiedConfig()
    let layout = UnifiedBatchLayout(config: config)
    let samples = [Float](repeating: 0, count: config.sampleRate)
    let starts = layout.chunkStarts(totalSamples: samples.count)
    #expect(starts == [0])
    let processor = ChunkProcessor(audioSamples: samples)
    let vocabulary = [1: "▁Yes", 2: "▁yes", 3: "."]
    let tokens: [ChunkProcessor.TokenWindow] = [
        (token: 1, timestamp: 2, confidence: 0.95, duration: 0),
        (token: 2, timestamp: 7, confidence: 0.95, duration: 0),
        (token: 3, timestamp: 7, confidence: 0.95, duration: 0)
    ]
    let result = processor.collapseSeamWordDuplicates(
        tokens, vocabulary: vocabulary, hasSeams: starts.count > 1)
    #expect(result.map(\.token) == [1, 2, 3])
}

@Test func unifiedMultipleWindowsRetainExistingSeamCleanup() {
    let config = UnifiedConfig()
    let layout = UnifiedBatchLayout(config: config)
    let samples = [Float](repeating: 0, count: 22 * config.sampleRate)
    let starts = layout.chunkStarts(totalSamples: samples.count)
    #expect(starts.count > 1)
    let processor = ChunkProcessor(audioSamples: samples)
    let vocabulary = [1: "▁yes", 2: "▁Yes", 3: "▁now"]
    let tokens: [ChunkProcessor.TokenWindow] = [
        (token: 1, timestamp: 170, confidence: 0.95, duration: 0),
        (token: 2, timestamp: 172, confidence: 0.95, duration: 0),
        (token: 3, timestamp: 172, confidence: 0.95, duration: 0)
    ]
    let result = processor.collapseSeamWordDuplicates(
        tokens, vocabulary: vocabulary, hasSeams: starts.count > 1)
    #expect(result.map(\.token) == [1, 3])
}
