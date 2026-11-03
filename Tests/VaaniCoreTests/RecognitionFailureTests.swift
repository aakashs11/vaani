import Testing
@testable import Vaani

@Test func emptyRecognitionDoesNotClaimTheMicrophoneHeardNothing() {
    let failure = DictationFailure.emptyTranscript(raw: " \n")
    #expect(failure.title == "Couldn’t recognize speech.")
    #expect(failure.message.contains("Audio was recorded"))
    #expect(failure != .noSpeech)
}

@Test func cleanupRemovingRecognizedWordsHasADistinctFailure() {
    let failure = DictationFailure.emptyTranscript(raw: "Thank you for watching.")
    #expect(failure.title == "No text remained after cleanup.")
    #expect(failure != DictationFailure.emptyTranscript(raw: ""))
    #expect(failure != .noSpeech)
}
