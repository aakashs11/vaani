# Dictation with speaker music

Enable **Settings → Microphone and language → Reduce speaker audio** after
downloading its 19 MB local model. macOS may request system-audio recording
permission. This feature needs macOS 14.2 or later.

Vaani records the microphone and a temporary reference of other applications'
playback during dictation. Playback stays unmuted and its volume is not changed.
The reference is aligned using capture timestamps, processed locally with
LocalVQE, and deleted when the recording is released. It is not archived or sent
to recognition APIs. The original microphone recording remains subject to the
existing saved-recording preference.

The selected recognizer remains unchanged. Provisional text is disabled while
speaker cleanup is active so it does not show words from unprocessed music.
Final recognition uses the enhanced recording. Quiet playback bypasses processing.
Unavailable permissions, interrupted reference timing, or processing errors use
ordinary microphone dictation. Capture/processing errors appear in Settings,
and metadata-only diagnostics record whether enhancement was applied.

“No speech heard” now applies to the microphone amplitude gate. Successful
capture followed by empty recognition shows “Couldn’t recognize speech.”
Text removed by cleanup has a separate message.

## Validation on November 4, 2026

The installed app's empty recognition was reproduced on three saved recordings.
Reducing peak level did not recover them. Noise suppression without a playback
reference recovered one, but removed words from other recordings, so it was
rejected as a general fix. Those recordings have no playback reference and
cannot retrospectively validate echo cancellation.

The controlled benchmark uses ten locally synthesized phrases (64 reference
words), three installed instrumental Apple Loops mixed together, and a simulated
room path with arrivals at 35, 65, and 110 ms. The same mixtures and selected
Parakeet Unified model are used in both conditions. No benchmark audio or private
transcripts are committed.

| Speech relative to music | Original empty results | Enhanced empty results | Original word errors | Enhanced word errors |
| --- | ---: | ---: | ---: | ---: |
| 20 dB louder | 0/10 | 0/10 | 2/64 | 2/64 |
| 10 dB louder | 0/10 | 0/10 | 2/64 | 2/64 |
| Equal level | 0/10 | 0/10 | 6/64 | 3/64 |
| 10 dB quieter | 10/10 | 0/10 | 64/64 | 40/64 |
| 20 dB quieter | 10/10 | 10/10 | 64/64 | 64/64 |

The music-only control remained empty. Synthetic quiet speech had 2/64 word
errors before processing; the production path bypasses processing without a
playback reference. Median added enhancement time in the debug production
pipeline was 209 ms for these short clips. This excludes capture startup, model
warm-up, recognition, and the bounded final-reference wait.

These are controlled offline results, not physical speaker measurements or a
general accuracy claim. Very loud music still masks words.

After installation and permission renewal, a live smoke test on the user's Mac
verified playback-reference capture, enhancement, recognition, and automatic
paste. The user confirmed that the words came through correctly with their
usual speaker music playing. Temporary playback and enhanced files were absent
after completion. This verifies the current setup, not accuracy at every volume.
Bluetooth/USB devices and concurrent meetings remain separate checks.

Later live testing exposed a confirmed short-phrase error while a football match
played on the same Mac. The user confirmed that the complete phrase was audible
in the original microphone recording. Capture truncation does not explain that
case. Commentary and crowd noise remain an unresolved recognition condition.

The updated GPU path processed one short live recording in 0.116 seconds and
delivered text 0.464 seconds after key release, but its first observed 11.700-second
recording took 4.363 seconds for cleanup and 5.134 seconds to paste. A subsequent
fresh-process fixture test did not reproduce that long delay. Warmed-up results
must not be presented as first-use or complete-pipeline guarantees. See the
[full comparison and live observations](model-comparison-20261104.md).

Automated verification includes the complete Swift suite, the existing
microphone lifecycle harness, offline missing-model behavior, backward-compatible
settings, silent-reference bypass, discontinuous timestamp rejection, delayed
final reference delivery, rounding, and temporary-reference deletion. An
independent review identified the final-buffer race, which is covered by a
regression test and a maximum 150 ms reference wait.

The local experiment scripts and outputs are in
`local/private/background-music-20261104/`. `make-room-fixtures.py` generates the
controlled mixtures. `ProductionProbe.swift` invokes the actual
`SpeakerAudioCleaner.process` path and the selected recognizer. The ordinary CLI
`--bench` mode supplies the unprocessed baseline. These local artifacts may
include private recordings and must not be committed.
