import Foundation
import AVFoundation
import Testing
@testable import VaaniCore

@Test func captureTimingRejectsGapsAndMissingTimestamps() {
    var timing = AudioCaptureTimeline()
    timing.append(start: 10, frames: 480, sampleRate: 48000)
    timing.append(start: 10.01, frames: 480, sampleRate: 48000)
    #expect(timing.start == 10)
    timing.append(start: 10.2, frames: 480, sampleRate: 48000)
    #expect(timing.start == nil)
    timing.append(start: 10.21, frames: 480, sampleRate: 48000)
    #expect(timing.start == nil)
    var missing = AudioCaptureTimeline()
    missing.append(start: nil, frames: 480, sampleRate: 48000)
    missing.append(start: 10, frames: 480, sampleRate: 48000)
    #expect(missing.start == nil)
}

@Test func playbackReferenceUsesCaptureTimesRatherThanCallbackArrival() throws {
    let samples = (0..<1600).map(Float.init)
    let aligned = try #require(SpeakerReferenceAlignment.align(samples, referenceStart: 10,
                                                              microphoneStart: 10.025, count: 800))
    #expect(aligned == Array(samples[400..<1200]))
    #expect(SpeakerReferenceAlignment.align(samples, referenceStart: 10, microphoneStart: 9, count: 800) == nil)
    #expect(SpeakerReferenceAlignment.align(samples, referenceStart: 10, microphoneStart: 10.1, count: 800) == nil)
    #expect(SpeakerReferenceAlignment.align(samples, referenceStart: .nan, microphoneStart: 10, count: 800) == nil)
    #expect(SpeakerReferenceAlignment.align(samples, referenceStart: 10, microphoneStart: 10, count: 1601)?.last == 0)
}

@Test func finalMicrophoneBufferWaitsForTheIndependentPlaybackCallback() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".caf")
    defer { try? FileManager.default.removeItem(at: url) }
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
    let writer = try RecordingWriter(url: url, format: format, threshold: 0)
    func deliver(at time: Double) {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 320)!
        buffer.frameLength = 320
        buffer.floatChannelData![0].initialize(repeating: 0, count: 320)
        _ = writer.write(buffer, at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: time)))
    }
    deliver(at: 10)
    let completion = Task {
        try await Task.sleep(for: .milliseconds(25))
        deliver(at: 10.02)
    }
    try await writer.waitForCapture(through: 10.04)
    try await completion.value
    #expect(try #require(writer.captureEnd) >= 10.04 - 0.000_001)
    _ = writer.finish()
}

@Test func temporarySpeakerReferenceIsRemovedWhenItsOwnerIsReleased() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try Data([1, 2, 3]).write(to: url)
    var reference: SpeakerAudioReference? = SpeakerAudioReference(url: url, start: 10)
    #expect(FileManager.default.fileExists(atPath: try #require(reference).url.path))
    reference = nil
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func speakerCleanupIsOptInForExistingSettings() throws {
    let data = try JSONEncoder().encode(AppSettings())
    var fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    fields.removeValue(forKey: "reduceSpeakerAudio")
    let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: fields))
    #expect(!decoded.reduceSpeakerAudio)
}

@Test func absentSpeakerCleanupModelFailsWithoutDownloading() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let cleaner = SpeakerAudioCleaner(directory: root)
    #expect(!SpeakerAudioCleaner.isInstalled(at: root))
    do {
        try await cleaner.prepare()
        Issue.record("Missing cleanup model must fail locally")
    } catch SpeechError.modelNotInstalled {
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
}

@Test func silentPlaybackBypassesEnhancementWithoutLoadingAModel() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1600))
    buffer.frameLength = 1600
    buffer.floatChannelData![0].initialize(repeating: 0, count: 1600)
    let mic = root.appending(path: "mic.caf"), ref = root.appending(path: "reference.caf")
    for url in [mic, ref] {
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
    let audio = RecordedAudio(url: mic, duration: 0.1, hasSpeech: false, captureStart: 1,
                              speakerReference: SpeakerAudioReference(url: ref, start: 1))
    let cleaner = SpeakerAudioCleaner(directory: root.appending(path: "absent-model"))
    #expect(try await cleaner.process(audio) == nil)
    #expect(FileManager.default.fileExists(atPath: mic.path))
    #expect(!FileManager.default.fileExists(atPath: root.appending(path: "absent-model").path))
}
