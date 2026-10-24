import AVFoundation
import Foundation
@testable import BetterWisprCore

@main struct MicrophoneStartupCheck {
    @MainActor static func main() async throws {
        if CommandLine.arguments.contains("--activity") {
            print("Microphone recording processes: \(MicrophoneActivity.recordingBundleIDs())")
            return
        }
        let recorder = AudioRecorder()
        recorder.invalidateMicrophonePreparation()
        precondition(!recorder.hasPreparedMicrophone)
        for rate in [16_000.0, 48_000.0] {
            let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 960)!
            buffer.frameLength = 960
            for index in 0..<960 { buffer.floatChannelData![0][index] = Float(index + 1) / 960 }
            let file = FileManager.default.temporaryDirectory.appending(path: "first-buffer-\(UUID()).caf")
            defer { try? FileManager.default.removeItem(at: file) }
            let writer = try RecordingWriter(url: file, format: format, threshold: 0)
            let delivery = MicrophoneDelivery(), id = UUID()
            delivery.add(id, since: 100) { pcm, _ in _ = writer.write(pcm) }
            delivery.receive(buffer, at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: 100)))
            delivery.remove(id)
            delivery.receive(buffer, at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: 100.1)))
            let result = writer.finish()
            precondition(result.error == nil)
            let audio = try AVAudioFile(forReading: file)
            precondition(audio.length == 960, "every first-buffer sample is preserved, detached audio is excluded")
            let read = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 960)!
            try audio.read(into: read)
            precondition(abs(read.floatChannelData![0][0] - 1 / 960.0) < 0.000001)
            precondition(read.floatChannelData![0][959] == 1)
        }
        let fake = FakeMicrophoneHardware()
        let source = MicrophoneInput.Source(hardware: fake)
        try await source.prepare()
        precondition(fake.starts == 0 && !fake.isRunning, "idle preparation must never start capture")
        let changedFormat = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        precondition(!source.canReuse(deviceID: fake.deviceID, format: changedFormat), "stale stopped preparation must be discarded")
        let first = UUID(), meeting = UUID()
        try await source.start(id: first, since: 100) { _, _ in }
        precondition(source.canReuse(deviceID: fake.deviceID, format: changedFormat), "running meeting keeps its shared conversion format")
        try await source.start(id: meeting, since: 100) { _, _ in }
        precondition(fake.starts == 1 && fake.isRunning)
        source.remove(first)
        precondition(fake.isRunning, "dictation must not stop an active meeting")
        source.remove(meeting)
        precondition(!fake.isRunning && fake.stops == 1)
        for duringStart in [false, true] {
            let delayed = FakeMicrophoneHardware(prepareDelay: duringStart ? 0 : 100, startDelay: duringStart ? 100 : 0)
            let delayedSource = MicrophoneInput.Source(hardware: delayed)
            let task = Task { try await delayedSource.start(id: UUID(), since: 100) { _, _ in } }
            try await Task.sleep(for: .milliseconds(10))
            task.cancel()
            do { try await task.value; preconditionFailure("cancelled start must fail") } catch is CancellationError {}
            precondition(!delayed.isRunning, "cancel must leave microphone off")
            if !duringStart { precondition(delayed.starts == 0, "cancel during preparation must prevent capture") }
        }
        print("PASS: stopped queue preparation; one shared start; independent detach; final subscriber shutdown; cancellation during prepare/start")
        print("PASS: preparation invalidation, first sample and full first buffer at 16/48 kHz, detached audio excluded")
    }
}

private final class FakeMicrophoneHardware: MicrophoneHardware, @unchecked Sendable {
    let device = AudioInputDevice(id: "test", name: "test")
    let deviceID: UInt32 = 0
    let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    let prepareDelay: Int
    let startDelay: Int
    private let lock = NSLock()
    private var running = false
    private var startCount = 0
    private var stopCount = 0
    var starts: Int { lock.withLock { startCount } }
    var stops: Int { lock.withLock { stopCount } }
    var isRunning: Bool { lock.withLock { running } }
    var error: (any Error)? { nil }
    init(prepareDelay: Int = 0, startDelay: Int = 0) {
        self.prepareDelay = prepareDelay; self.startDelay = startDelay
    }
    func prepare(receive: @escaping @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void) async throws {
        if prepareDelay > 0 { try await Task.sleep(for: .milliseconds(prepareDelay)) }
    }
    func start() async throws {
        lock.withLock { startCount += 1 }
        if startDelay > 0 { try await Task.sleep(for: .milliseconds(startDelay)) }
        lock.withLock { running = true }
    }
    func stop() { lock.withLock { if running { running = false; stopCount += 1 } } }
}
