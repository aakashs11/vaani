@preconcurrency import AVFoundation
import Foundation

/// Records playback only while dictation is active. The tap is explicitly unmuted.
@MainActor
final class SpeakerReferenceRecorder {
    private var stopTap: (() -> Void)?
    private var writer: RecordingWriter?
    private var url: URL?
    private var generation = UUID()

    func start() async throws {
        guard #available(macOS 14.2, *) else {
            throw NSError(domain: "Vaani.SpeakerCleanup", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Speaker cleanup needs macOS 14.2 or later."])
        }
        cancel()
        let token = generation
        let tap = SystemAudioTap()
        let url = FileManager.default.temporaryDirectory.appending(path: "vaani-speaker-\(UUID()).caf")
        do {
            let format = try await tap.prepare()
            try Task.checkCancellation()
            guard generation == token else { throw CancellationError() }
            let writer = try RecordingWriter(url: url, format: format, threshold: 0)
            try tap.start { buffers, time in
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: buffers, deallocator: nil) else { return }
                _ = writer.write(buffer, at: AVAudioTime(audioTimeStamp: time, sampleRate: format.sampleRate))
            }
            self.url = url
            self.writer = writer
            stopTap = { tap.stop() }
        } catch {
            tap.stop()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func finish() -> SpeakerAudioReference? {
        stopTap?()
        stopTap = nil
        let result = writer?.finish()
        writer = nil
        guard let url else { return nil }
        self.url = nil
        guard let result, result.error == nil, let start = result.captureStart else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return SpeakerAudioReference(url: url, start: start)
    }

    func waitForCapture(through end: TimeInterval) async throws {
        try await writer?.waitForCapture(through: end)
    }

    func cancel() {
        generation = UUID()
        _ = finish()
    }

    isolated deinit { cancel() }
}
