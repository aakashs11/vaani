import AVFoundation
import Testing
@testable import VaaniCore

@Test(arguments: [1, 2, 3, 4, 8] as [AVAudioChannelCount])
func microphoneCaptureSupportsChannelArrays(channels: AVAudioChannelCount) throws {
    let format = try #require(AudioInputs.captureFormat(sampleRate: 48_000, channels: channels))
    #expect(format.channelCount == channels)
    #expect(format.sampleRate == 48_000)
    #expect(format.isInterleaved)
    #expect(format.commonFormat == .pcmFormatFloat32)
    #expect(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 960) != nil)
}

@Test
func microphoneCaptureRejectsInvalidFormats() {
    #expect(AudioInputs.captureFormat(sampleRate: 0, channels: 1) == nil)
    #expect(AudioInputs.captureFormat(sampleRate: .nan, channels: 1) == nil)
    #expect(AudioInputs.captureFormat(sampleRate: .infinity, channels: 1) == nil)
    #expect(AudioInputs.captureFormat(sampleRate: 48_000, channels: 0) == nil)
    #expect(AudioInputs.captureFormat(sampleRate: 48_000, channels: 65_536) == nil)
}
