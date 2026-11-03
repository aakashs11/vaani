@preconcurrency import AVFoundation
import FluidAudio
import Foundation

/// Owns a temporary playback recording. It is never saved with dictation history or uploaded.
public final class SpeakerAudioReference: Sendable {
    let url: URL
    let start: TimeInterval

    init(url: URL, start: TimeInterval) {
        self.url = url
        self.start = start
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}

/// A discontinuous recording cannot be aligned using a single start timestamp.
struct AudioCaptureTimeline {
    private var first: TimeInterval?
    private var next: TimeInterval?
    private var valid = true
    var start: TimeInterval? { valid ? first : nil }

    mutating func append(start: TimeInterval?, frames: Int, sampleRate: Double) {
        guard frames > 0 else { return }
        guard valid, let start, start.isFinite, sampleRate.isFinite, sampleRate > 0 else {
            valid = false
            return
        }
        if let next, abs(start - next) > 0.025 { valid = false }
        if first == nil { first = start }
        next = (next ?? start) + Double(frames) / sampleRate
    }
}

enum SpeakerReferenceAlignment {
    static func align(_ samples: [Float], referenceStart: TimeInterval,
                      microphoneStart: TimeInterval, count: Int) -> [Float]? {
        let offset = ((microphoneStart - referenceStart) * 16_000).rounded()
        guard offset.isFinite, offset >= 0, offset < Double(samples.count), count > 0 else { return nil }
        let available = samples.count - Int(offset)
        // Independently resampled clocks can differ by one final sample after rounding.
        guard count <= available || count - available == 1 else { return nil }
        var aligned = Array(samples[Int(offset)..<(Int(offset) + min(count, available))])
        if aligned.count < count { aligned.append(0) }
        return aligned
    }
}

/// Local acoustic echo cancellation. Loading never downloads models, and silent playback is bypassed.
public actor SpeakerAudioCleaner {
    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Vaani/Models/localvqe", directoryHint: .isDirectory)
    }
    private static var modelName: String {
        ModelNames.LocalVQE.modelFile(variant: .v13, chunk: .batch256ms)
    }
    private let directory: URL
    private var manager: LocalVqeManager?
    public private(set) var computeUnitsDescription = "notLoaded"

    public init(directory: URL = defaultDirectory) { self.directory = directory }

    public static func isInstalled(at directory: URL = defaultDirectory) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: modelName + "/coremldata.bin").path)
            && FileManager.default.fileExists(atPath: directory.appending(path: ".vaani-installed").path)
    }

    /// Only called by the explicit Download action.
    public static func install(at directory: URL = defaultDirectory,
                               progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await ModelHub.download(.localVqe, to: directory.deletingLastPathComponent(),
                                    variant: ModelNames.LocalVQE.variantKey(variant: .v13, chunk: .batch256ms)) {
            progress?(min(0.95, $0.fractionCompleted))
        }
        try Task.checkCancellation()
        _ = try LocalVqeManager(modelDirectory: directory)
        try Task.checkCancellation()
        try Data("localvqe-v1.3-256ms".utf8).write(to: directory.appending(path: ".vaani-installed"), options: .atomic)
        progress?(1)
    }

    public func prepare() throws {
        guard manager == nil else { return }
        guard Self.isInstalled(at: directory) else { throw SpeechError.modelNotInstalled("Speaker cleanup") }
        // Keep float32 processing, using the GPU where Core ML supports it.
        // CPU remains available on machines that cannot build that execution plan.
        do {
            manager = try LocalVqeManager(config: .init(computeUnits: .cpuAndGPU), modelDirectory: directory)
            computeUnitsDescription = "cpuAndGPU"
        } catch {
            try Task.checkCancellation()
            manager = try LocalVqeManager(modelDirectory: directory)
            computeUnitsDescription = "cpuOnly"
        }
    }

    /// Returns a temporary enhanced file owned by the caller, or nil when no reliable reference is available.
    public func process(_ audio: RecordedAudio) async throws -> URL? {
        try Task.checkCancellation()
        guard let reference = audio.speakerReference, let microphoneStart = audio.captureStart else { return nil }
        let converter = AudioConverter()
        let microphone = try converter.resampleAudioFile(audio.url)
        let playback = try converter.resampleAudioFile(reference.url)
        guard let aligned = SpeakerReferenceAlignment.align(playback, referenceStart: reference.start,
                                                            microphoneStart: microphoneStart, count: microphone.count),
              microphone.allSatisfy(\.isFinite), aligned.allSatisfy(\.isFinite) else { return nil }
        // Avoid denoising quiet-room recordings: the no-reference prototype degraded some speech.
        let energy = aligned.reduce(Float(0)) { $0 + $1 * $1 } / Float(aligned.count)
        guard energy > 0.000_001 else { return nil }
        try prepare()
        try Task.checkCancellation()
        guard let manager else { return nil }
        let peak = max(microphone.map(abs).max() ?? 0, aligned.map(abs).max() ?? 0)
        let gain: Float = peak > 0.95 ? 0.95 / peak : 1
        let cleaned = try await manager.process(mic: microphone.map { $0 * gain }, reference: aligned.map { $0 * gain })
        try Task.checkCancellation()
        guard cleaned.count == microphone.count, cleaned.allSatisfy(\.isFinite) else {
            throw LocalVqeError.modelProcessingFailed("Invalid enhanced audio")
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "vaani-cleaned-\(UUID()).caf")
        do {
            let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(cleaned.count)) else {
                throw AudioRecordingError.unavailable
            }
            buffer.frameLength = AVAudioFrameCount(cleaned.count)
            cleaned.withUnsafeBufferPointer {
                buffer.floatChannelData![0].update(from: $0.baseAddress!, count: cleaned.count)
            }
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            try Task.checkCancellation()
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}
