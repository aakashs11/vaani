# Dictation development checkpoint — November 4, 2026

Recognition experiments are paused at this checkpoint. The tested changes are
consolidated for source review, and the development app is installed locally.
This is not a new notarized binary release. The existing recognizer selection
and vocabulary settings are preserved.

## Included changes

- Optional speaker cleanup captures this Mac's playback reference during
  dictation and applies the installed 19 MB LocalVQE model locally. Playback
  continues normally. The reference is temporary and separate from saved
  microphone evidence.
- Parakeet Unified uses its dedicated recognizer. A narrowly scoped,
  version-checked FluidAudio patch preserves repetitions inside a single
  recognition window. Text cleanup also preserves repeated utterances at clause
  boundaries.
- Vocabulary CTC assets load only when eligible hints need them. Changing
  recognizers releases the previous booster state.
- Microphone startup refreshes the current device format before reusing prepared
  capture. Failure messages distinguish capture, recognition, and text cleanup.
- Migration hashing releases temporary buffers one chunk at a time without
  weakening source checks, receipt validation, or recovery.
- `make verify` runs unit/tooling checks and every registered local accuracy and
  latency suite. Missing assets fail the gate. Private corpora remain outside Git.

## Measured outcomes

Measurements below are from an M4 Pro with 48 GiB RAM, not the target M1 Air
with 8 GB RAM. The English corpus contains 32 human recordings and 113 synthetic
variants, so its aggregate score is not a broad accuracy estimate.

| Change | Evidence | Limit |
| --- | --- | --- |
| Single-window repetition patch | Word errors fell from 165 to 164 across 145 clips. The other 144 raw outputs were unchanged. | One repaired deletion, not a general recognition fix. |
| GPU-assisted speaker cleanup | Median paired processing ratio was 0.767 across 54 fixtures, about 23% faster. Aggregate recognition errors stayed equal. | Warm processing only. Standalone peak RSS increased by about 27 MiB. |
| Migration buffer lifetime | Repeated isolated hashing used about 9.7 MB peak RSS instead of 1,050 MB, with identical hashes. Full CLI peak RSS fell from 1.84 to 0.64 GiB in one before/after run. | CLI startup plus recognition, not whole-app memory or a guaranteed steady-state ceiling. |
| Model comparison | Six installed English models, two Hindi models, and matched vocabulary-enabled/disabled runs were evaluated. | Smaller models did not justify replacing the selected Unified model. |

The pre-install verified tree passed 187 Swift tests, standalone preservation and
packaging checks, and all four registered accuracy/latency suites. The installed
release bundle passed signing and branding checks. Live use confirmed microphone
capture, GPU cleanup, and paste dispatch after permission renewal.

The first consolidation rerun again passed 187 Swift tests and all accuracy
checks, but failed the latency gate for the pilot and scripted suites. Their
recognition p50 ratios were 2.44 and 1.34, and p95 ratios were 3.14 and 1.61,
against unchanged baselines. The later synthetic and human-short suites passed
both gates. The failed run is retained. Other CPU activity was observed after
the run, which is a possible contributor, not a proven explanation.

A single repeat of the unchanged gate stopped in the Swift tests before corpus
evaluation. `microphoneObserverCoalescesChangesAndIgnoresThemAfterCancel` and
`liveTranscriberPassesOnlyWhileRunningAndOnlyOverNewAudio` failed callback/timing
expectations. Their cause has not been established. Both runs are retained in
the private evaluation logs, and no baseline or threshold was relaxed.

Source publication is therefore a draft for review, not a claim that the latest
verification is green. Further investigation is paused. Do not merge or create
a new binary release until the current test and latency gates pass with the
failure causes understood. The installed app remains the previously verified
release executable.

## Known limitations

Football commentary and crowd noise still caused a short-phrase recognition
failure. The user confirmed that the entire phrase was audible in the original
microphone recording, so missing capture of the beginning does not explain this
case. Replaying the unprocessed recording through three installed Parakeet
models also failed. The temporary playback reference and enhanced audio were
not retained, so the exact cleanup cannot be replayed.

The first observed updated-app recording lasted 11.700 seconds and took
5.134 seconds from key release to paste, including 4.363 seconds of cleanup.
A later short recording took 0.464 seconds overall. A fresh-process fixture
probe did not reproduce the long delay. First-use initialization is a hypothesis,
not a confirmed explanation.

The Hindi comparison contains only 20 public FLEURS clips and no Hinglish or
short-command coverage. Its results do not establish conversational Hindi
accuracy. No new multilingual engine is selected or downloaded as part of this
checkpoint. M1 Air memory pressure, sustained performance, Bluetooth/USB behavior,
and complete physical regression coverage remain unverified.

## Paused follow-up

Before another recognition change, collect a controlled, explicitly reviewed
voice-plus-football example with a playback reference. Compare alignment and
cleanup settings while checking speech preservation, latency, and memory.
Measure first-use loading and processing separately. Cleanup during recording
is a possible later optimization, but has not been implemented or validated.
No additional model is justified without a clear measured improvement.

## Supporting documents

- [Speaker cleanup setup, privacy, and controlled fixtures](background-music.md)
- [Full model, vocabulary, memory, and live timing comparison](model-comparison-20261104.md)
- [English/Hindi model and research review](asr-model-research-20261104.md)
- [Local benchmark setup and scoring rules](dictation-benchmark.md)
- [Verification and physical checks](testing.md)
- [Dependency patch maintenance](../patches/README.md)
- [Privacy and retention](privacy.md)

The repository contains aggregate findings, source, tests, and patch provenance.
It does not contain private recordings, transcript archives, vocabulary snapshots,
installed models, or local benchmark outputs.
