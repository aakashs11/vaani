# Local model and latency comparison, 2026-11-04

The completed release-profile English comparison does **not** justify changing
Unified as the selected default. Parakeet 110M is considerably faster in the
recognition-only test, but makes more errors on the human subset. Whisper Small
does not improve this English corpus or the completed release Hindi results. The
single-window repetition fix recovers one known deletion without changing the
other 144 raw transcripts in its paired debug comparison. A paired speaker-audio
cleanup experiment is about 23% faster with GPU compute, but its benefit to the
complete live app still needs a post-install measurement.

**Status at this report snapshot:** all six bare-model English release runs are
complete with exit code 0, as are both release Hindi runs and all six corrected
workspace-vocabulary runs. The latter compare disabled and enabled vocabulary
within one macOS 14-targeted executable, with one pass per mode and model.
The pre-install `make verify` passed all four registered accuracy/latency suites,
187 Swift tests, and the extended standalone migration check. The release bundle
passed signature and branding checks and was installed in `/Applications/Vaani.app`,
with a verified recoverable backup. Its executable SHA-256 is
`add1b2dd569016c04da220943a6fc31501fc300e28df18e32ac3cf48754fe81d`.
The app shows microphone access and Accessibility paste access restored, with
Unified still selected. System-audio-only permission was also renewed.
Post-install live testing now confirms that GPU cleanup and paste dispatch run,
but also exposes a slow first observed cleanup and a user-confirmed recognition
failure. These findings do not support claiming a complete live accuracy or
latency improvement.

See the [consolidation checkpoint](dictation-update-20261104.md) for later
verification runs, including the retained latency-gate failure during source
publication. Earlier passing measurements do not override later failures.

## Hardware, artifacts, and measurement boundaries

The machine is an **Apple M4 Pro with 48 GiB RAM**, running macOS **26.6.2**. The
requested M1 Air with 8 GB RAM has not been measured. Neither elapsed time nor
peak memory here proves that a configuration will perform acceptably there.

The final English table uses the release CLI with SHA-256
`1e0af888c434f3d6f169430425e07e0f6b1b6ce4b9394237ea4adfcc804f2f07`.
`release-metadata.json` records the companion vocabulary-probe hash. The private
artifacts are under `local/private/model-comparison-20261104/`. Audio, individual
transcripts, and vocabulary are not reproduced in this report.

Each model processes the same manifest in a separate process, using English
and light text cleanup. The model is prepared once before processing its clips.
The per-clip `seconds` field measures recognition through the provider. It
excludes initial model preparation, microphone capture/drain, speaker-audio
cleanup, paste dispatch, and target-app rendering. The raw tables also exclude
`cleanupSeconds`. These are file recognizer comparisons, not push-to-talk
completion measurements. Run order is fixed, with one final release pass per
model. Earlier debug repetitions do not create a repeated release experiment.

`/usr/bin/time -l` records process peak RSS and memory footprint. RSS is not model
size, total system memory pressure, or a guarantee about all accelerator/service
allocations. Release RSS covers the complete 153-clip process, including its
8 latency-only recordings, while accuracy scoring uses only the 145 verified
rows. Preparation times vary greatly in this run, including about 22 seconds
for Small and 190 seconds for compressed Turbo. They are observed process
preparation costs, not a controlled cold-start comparison or warm per-dictation
cost.

The CLI also invokes legacy identity migration before preparing the provider.
The vocabulary probe does not. The migration path inspects and hashes existing
model files, so CLI process peak RSS includes work outside recognition. The
isolated hashing result below establishes one allocation problem in that path.
Do not interpret the CLI RSS
column as recognizer-only memory or compare it directly with the probe to infer
a model-memory reduction.

## Startup migration memory fix

A standalone paired hashing experiment reads the same 1,039,398,528-byte legacy
model file using the migration digest loop. The original loop retains bridged
read buffers until its surrounding autorelease pool drains. The corrected loop
drains a local autorelease pool after each 1 MiB chunk. Four runs alternate
plain, pooled, pooled, plain, with two observations per implementation.

| Digest loop | Process peak RSS | Peak footprint | Wall time |
| --- | ---: | ---: | ---: |
| Original, two runs | 1,050.001 / 1,050.018 MB | 1,045.939 / 1,045.956 MB | 0.475 / 0.466 s |
| Per-chunk pool, two runs | 9.667 / 9.667 MB | 5.096 / 5.096 MB | 0.411 / 0.408 s |

All four digests match. These decimal MB figures describe the isolated hash
process, not model recognition. The production change adds only the per-chunk
autorelease pool to the migration digest loop. It changes no model or ASR logic.
The existing migration check was extended to exercise a multi-chunk receipt.

The six-model release comparison below predates this startup fix, and its CLI
hash and RSS measurements remain attributed to that earlier binary. The final
release CLI has SHA-256
`eece535632c0331120a4e82cfc138c146581f39c2ed276306630c42b18142e0a`.
A completed post-fix Unified run processes the same 153 clip IDs. Every raw and
light-cleaned transcript is byte-for-byte identical to the earlier release
output, including the eight latency-only clips. Accuracy still uses only the
145 verified references: 164 word errors, 17.85% WER, 67.61% exact phrase match,
20 empty speech outputs, and zero false speech outputs.

| Unified full CLI process | Peak RSS | Peak footprint |
| --- | ---: | ---: |
| Earlier release, before migration fix | 1,976,057,856 bytes (1.84 GiB) | 1,366,444,120 bytes |
| Final release, after migration fix | 689,881,088 bytes (0.64 GiB) | 81,232,640 bytes |

This is an observed full-process reduction in one run before and one after,
consistent with the isolated hashing experiment. It includes migration and
model preparation, and does not isolate recognizer allocations. Preparation in
the final run takes 15.608 seconds. Verified-clip recognition p50/p95 is
40/47 milliseconds, or 40/48 milliseconds including light cleanup. Cache and
run-order effects prevent attributing that timing change to the memory fix.
The final verification log reports the four-suite evaluation pass. Neither
this CLI result nor the isolated hashing result is a live-app or M1 Air memory
measurement.

## Corpus and scoring

| Subset | Clips | What the references establish |
| --- | ---: | --- |
| Human short and repetition cases | 12 | User confirmations and corrections in chat. One saved recording was explicitly listened to and confirmed truncated. Most were not independently transcribed by a second listener. |
| Human scripted sentences | 20 | User confirmed reading all sentences as written. No independent listening verification. |
| Synthetic room/music/quiet fixtures and negative controls | 113 | Known generated text and controlled mixtures. Repeated phrases and related mixtures are not independent speakers or utterance types. |
| Retained long recordings, latency only | 8 | No verified references. Never score their placeholder empty references as silence. |
| Hindi FLEURS test slice | 20 | Publisher-provided references, not independently human-reviewed here. |

The English accuracy set contains 145 clips, 919 normalized reference words,
142 speech clips, and 3 annotated no-speech controls. The human subset is 32
clips and 215 normalized words. Duration coverage is uneven: 9 clips are at most
1 second, 135 are over 1 through 5 seconds, and only 1 is over 5 through 15
seconds. There are no verified long English accuracy clips in that set.
Synthetic fixtures therefore dominate the aggregate score.

The eight retained latency-only recordings total 168.737 seconds and are all
over 15 seconds. Seven overlap the historical long-record latency audit. One
historical recording had already disappeared from retention and was replaced
by a different available long recording. These are not an identical before/after
set for the historical app timings.

Scores use the existing NFC/lowercase/letters-marks-numbers normalizer. WER is
corpus-weighted word edit count divided by reference words. Exact match compares
normalized full utterances on speech rows. Case and punctuation are ignored,
but spoken numbers versus digits, spelling variants, token splitting, and
Hindi script/orthography can still affect scores. CER counts Unicode code
points rather than grapheme clusters. No number rewriting or transliteration
was applied to improve results.

## Completed release English results

Raw recognition, 145 verified clips. p50/p95 use nearest-rank quantiles, in
milliseconds. False speech counts the 3 annotated no-speech controls.

| Model | Word errors | WER | Exact phrase match | Empty speech | False speech | Recognition p50 / p95 | Process peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Unified, patched | 164 | 17.85% | 67.61% | 20/142 | 0/3 | 67 / 95 ms | 1.84 GiB |
| Parakeet v3 | 151 | 16.43% | 72.54% | 19/142 | 0/3 | 52 / 234 ms | 1.62 GiB |
| Parakeet Ultra | 159 | 17.30% | 67.61% | 19/142 | 0/3 | 49 / 239 ms | 1.84 GiB |
| Parakeet 110M | 169 | 18.39% | 66.90% | 21/142 | 0/3 | 19 / 28 ms | 1.47 GiB |
| Whisper Small | 193 | 21.00% | 57.04% | 10/142 | 2/3 | 151 / 201 ms | 1.57 GiB |
| Whisper Turbo compressed | 181 | 19.70% | 60.56% | 11/142 | 2/3 | 412 / 544 ms | 1.94 GiB |

Light text cleanup leaves these word-error totals unchanged except for v3,
Ultra, and 110M, where it adds one error each: 152, 160, and 170 respectively.
Thus raw recognition and final cleaned text should remain separate results.
With only three negative controls, the false-speech counts are descriptive,
not a stable estimate of real-world hallucination frequency.

The human subset makes the smaller-model accuracy tradeoff clearer:

| Model | Errors / 215 words | Human-subset WER | Exact clips / 32 |
| --- | ---: | ---: | ---: |
| Unified, patched | 15 | 6.98% | 25 |
| Parakeet v3 | 8 | 3.72% | 28 |
| Parakeet Ultra | 12 | 5.58% | 25 |
| Parakeet 110M | 22 | 10.23% | 19 |
| Whisper Small | 36 | 16.74% | 13 |
| Whisper Turbo compressed | 29 | 13.49% | 17 |

These results do not establish a broad quality ranking. Number formatting favors
some outputs under the fixed normalizer, and the references have the limitations
above. Inspect error classes before interpreting a small WER difference as a
semantic gain. In the scripted number case, recognizing “thirty” where the
reference intends “thirteen” remains an actual recognition error rather than a
punctuation or digit-format difference.

Using patched Unified as the release reference, the current raw no-regression
accuracy gate passes for v3 but its p95 is 2.47 times Unified's, exceeding the
10% latency allowance. 110M passes the timing gate but fails accuracy, including
human-short and repetition categories. Ultra and both Whisper candidates fail
both gates. This is the result of these specific files and gates, not a claim
that one model is universally faster or better. A no-vocabulary run also cannot
predict the v3 path with the user's actual vocabulary enabled.

For the eight unscored long recordings, recognition-only times are:

| Model | p50 | p95 |
| --- | ---: | ---: |
| Unified | 0.489 s | 0.610 s |
| Parakeet v3 | 0.238 s | 0.341 s |
| Parakeet Ultra | 0.500 s | 0.960 s |
| Parakeet 110M | 0.163 s | 0.203 s |
| Whisper Small | 0.610 s | 0.765 s |
| Whisper Turbo compressed | 0.857 s | 1.020 s |

The p95 is simply the maximum with eight observations. No accuracy claim is
possible for these recordings. Their CLI path does not reproduce the historical
app's speaker cleanup or microphone finalization.

## Completed matched workspace-vocabulary comparison

The corrected probe uses the same release executable and macOS 14 deployment
target for both modes. Its SHA-256 is
`b58662c886330d9425e0a1127ae02d366c6953b272ac8cfaa5af01cbcdd7b1fd`.
Each mode runs once in a fresh process with identical input order. Workspace
mode loads 20 entries producing 18 hints. Their contents remain private.
Ordering is counterbalanced between models, but OS and CoreML caches can persist.
These are six successful single-pass runs, not repeated timing estimates.

Only the 145 verified rows enter accuracy scoring. “Raw” here is the provider's
returned hypothesis, including acoustic vocabulary boosting where supported.
“Final text” additionally applies the workspace none/light cleanup setting,
spoken commands, and explicit dictionary corrections. It excludes app modes,
style, email composition, LLM processing, capture, speaker cleanup, and delivery.
Both vocabulary modes apply the command-processing stage. This final-text path
therefore differs from the earlier CLI table's light-only cleanup. Literal
transcription references can penalize intended command transformations, so its
error counts should not be treated as a separate semantic-quality judgment.

| Model | Vocabulary | Raw errors / 919 words | Raw human errors / 215 words | Final-text errors | Recognition p50 / p95 | Recognition + text stages p50 / p95 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Unified | Disabled | 164 | 15 | 170 | 45 / 53 ms | 45 / 53 ms |
| Unified | Workspace | 164 | 15 | 168 | 44 / 61 ms | 49 / 67 ms |
| Parakeet v3 | Disabled | 151 | 8 | 161 | 39 / 204 ms | 40 / 204 ms |
| Parakeet v3 | Workspace | 153 | 10 | 163 | 149 / 204 ms | 152 / 208 ms |
| Parakeet 110M | Disabled | 169 | 22 | 186 | 15 / 19 ms | 16 / 19 ms |
| Parakeet 110M | Workspace | 169 | 22 | 186 | 119 / 132 ms | 123 / 135 ms |

All six runs produce zero false-speech outputs on the three controls. Empty
speech counts are unchanged within each pair: Unified 20, v3 19, and 110M 21.
Unified's raw hypotheses are unchanged. v3 acoustic boosting changes five
hypotheses and increases total and human-subset errors by two. 110M changes two
hypotheses, leaving aggregate errors unchanged while regressing the human-short
category. Its raw exact-match rate also falls from 66.90% to 66.20%. The category
gate catches this regression that the aggregate count would hide. Neither v3
nor 110M passes the paired raw accuracy gate.

Workspace recognition p50 is 3.80 times disabled for v3 and 7.87 times disabled
for 110M. Their first-call times are 14.396 and 0.295 seconds respectively.
Excluding that call leaves workspace medians about 149 and 119 milliseconds,
so the median increases do not come solely from the first call. Model
preparation is outside those per-clip times. Unified passes the raw accuracy
gate but misses the 10% p95 timing gate, rising from 53 to 61 milliseconds.
One pass cannot establish whether that smaller timing difference is reproducible.
None of the three workspace comparisons passes both literal gates.

Process peak RSS varies sharply with process order and preparation state. For
example, Unified disabled records about 0.64 GiB, versus 0.09 GiB with workspace
vocabulary, while their reported peak footprints are only about 90 and 96 MB.
This does not establish that vocabulary reduces model memory. Neither these
process measurements nor the migration-inclusive CLI peaks establish memory
pressure or safe operation on an M1 Air with 8 GB RAM.

## Repetition fix: small measured gain, limited scope

The paired debug experiment uses 145 clips, with two baseline and two candidate
runs. Unified has 165 word errors before and 164 after, recovering the known
intentional repetition. The other 144 raw transcripts are unchanged. The change
skips cross-window seam deduplication for a single Unified window, where no seam
exists. It does not disable the overlapping-window merge rule for actual
multi-window recognition.

This is one repaired deletion, a 0.11 percentage-point corpus WER reduction,
not a general accuracy breakthrough. It does not establish that the capture
path caused the earlier name omissions. Debug latency and memory are kept in
`installed-summary.json` and `after-small-summary.json`; they are not mixed
with the optimized release table.

## Completed release Hindi results

The deterministic FLEURS slice contains the first 20 WAV entries in the
publisher's Hindi test archive, selected before recognition and matched to its
TSV by filename. The dataset revision is
`70bb2e84b976b7e960aa89f1c648e09c59f894dd`, licensed CC-BY-4.0. The local
provenance records exact hashes. It contains 234.66 seconds and 527 normalized
reference words. Seventeen clips are 5–15 seconds and three exceed 15 seconds.
There is no short-command or Hinglish coverage.

Both final release runs exited successfully and used the same CLI binary and
Hindi manifest. Raw results are:

| Model | Word errors | WER | CER | Recognition p50 / p95 |
| --- | ---: | ---: | ---: | ---: |
| Whisper Turbo compressed | 267 | 50.66% | 24.90% | 1.434 / 4.774 s |
| Whisper Small | 353 | 66.98% | 35.08% | 2.458 / 5.570 s |

Light cleanup did not change either word-error total. Both returned nonempty
output for all 20 clips, with no normalized exact full matches. Small did not
improve this slice. These are poor enough results to warrant investigation, but
do not establish the error rate for conversational Hindi or Hinglish. Script
and word-boundary differences also affect WER, which is why CER is included.
No silence controls were present, so this slice cannot estimate false speech.

For provenance, the earlier exploratory debug runs had 260 errors for compressed
Turbo (49.34% WER, 21.29% CER) and 360 for Small (68.31% WER, 35.54% CER).
Those transcripts differ from the final release outputs. They are separate runs
and should not be pooled with release or treated as repeated measurements of an
identical execution configuration. The completed release table above supersedes
the provisional debug table for this comparison.

Source: [Google FLEURS dataset](https://huggingface.co/datasets/google/fleurs)
and [FLEURS paper](https://arxiv.org/abs/2205.12446). The slice preparation uses
only bounded archive prefixes, not the complete audio archive.

## Speaker-audio cleanup and actual app latency

The historical retained-record audit contains 54 records, of which 49 have
completed delivery timings. It is a convenience sample from October 23 through
November 3, not a controlled benchmark. Median release-to-paste-event-dispatch
was 0.472 seconds for at-most-1-second audio, 0.565 seconds for 1–5 seconds,
0.951 seconds for 5–15 seconds, and 1.482 seconds for the eight longer recordings.
This measures the app posting a paste event, not the target app rendering text.

For the long group, median speaker cleanup was 1.029 seconds across seven
measured cleanup events, versus 0.204 seconds recognition and 0.205 seconds
capture drain across eight records. The stage medians have different
observations and must not be added. In the 27.34-second example, total
release-to-dispatch was 1.732 seconds, including 1.251 seconds of speaker cleanup.
The evidence points to serial whole-clip speaker cleanup as the principal
long-record bottleneck. It does not support blaming text cleanup or the
asynchronous clipboard-restoration timer.

A separate paired LocalVQE probe ran the same 54 controlled fixtures with CPU
and GPU compute. Its recorded processing totals were 7.458 seconds on CPU and
5.716 seconds on GPU. The median per-clip GPU/CPU ratio was 0.767, approximately
23% faster. On the three long fixtures, totals were 3.268 versus 2.495 seconds.
Standalone peak RSS increased from approximately 126 MB to 154 MB. Waveform
outputs were close but not identical: maximum absolute sample difference was
`1.71e-6`, with maximum RMS difference `1.00e-7`.

Recognizing the paired cleanup outputs yielded 193 word errors in both cases
on 560 reference words. One already-inaccurate noise clip changed its raw text,
and no previously exact clip regressed. The category accuracy gate passed.
This supports the bounded compute-unit experiment. It does not establish
identical audio or a 23% reduction in total release-to-paste time. No new
paired before/after live app timing is available.

### Post-install observations

The first observed updated-app recording lasted 11.700 seconds. Key release to
paste dispatch took 5.134 seconds, including 4.363 seconds in speaker cleanup,
0.542 seconds in recognition, and 0.197 seconds in capture finalization.
Cleanup was applied with `cpuAndGPU`. The user changed the wording of the
suggested prompt, so that prompt must not be used as its reference transcript.
The user reports recognition mistakes, but this recording has no verified full
reference.

A subsequent 1.999-second recording has a user-confirmed correction. Its
two-word opening was replaced by an incorrect word. Delivery took 0.464 seconds,
including 0.116 seconds of GPU cleanup and 0.126 seconds of recognition.
Replaying the retained original microphone audio through Unified, v3, and 110M
produced incorrect alternatives in all three cases. These raw-audio replays
exclude the live echo-cleanup stage. The playback reference and enhanced file
were deleted after dictation, so the exact live cleanup cannot be replayed or
compared against CPU processing.

The user subsequently confirmed that the full phrase, including its opening,
is audible in the original recording and that a football match was playing on
the same Mac. Capture truncation does not explain this example. Commentary/noise
separation remains unresolved. Further experiments are paused at the
[consolidated development checkpoint](dictation-update-20261104.md).

A diagnostic fresh-process probe on the same 13.920-second paired fixture ran
CPU/GPU/GPU/CPU. Model load plus first processing took 0.49–0.73 seconds on CPU
and 0.50–0.73 seconds on GPU. Repeated processing took 0.45–0.47 seconds on CPU
and 0.30–0.31 seconds on GPU. It did not reproduce the live 4.363-second delay.
Core ML caches were already populated and were not cleared. One-time
initialization remains a hypothesis, not an established explanation. The
23% warmed-up improvement must not be presented as proof of faster first use.

Private evidence is preserved under `live-after/` and
`cold-vqe-20261103T204951Z/`. The confirmed short phrase is a new diagnostic
case, separate from the original 145-clip comparison.

The VQE comparison uses the same release implementation on both sides, with
its relevant dependency code unchanged. The initial workspace-vocabulary probe
was different: it linked older release objects, while bare-model runs used newer
debug objects. That initial comparison is confounded by source age and build
profile and must not be interpreted as the effect of vocabulary alone. A
current-release probe was relinked, but its first build targeted macOS 26 while
the CLI targeted macOS 14. That is another execution-configuration difference,
so even those release-vocabulary outputs do not isolate vocabulary effects.
The completed corrected experiment above uses a macOS 14 target and compares
disabled versus workspace vocabulary within the same executable. The older
probe outputs remain excluded from the paired conclusions.

## Decisions and remaining evidence

Keep the selected default unchanged on these results. 110M is a useful optional
speed candidate, but its short human/repetition regressions prevent calling it
an accuracy improvement. Whisper Small is not supported as the replacement by
either the completed English table or release Hindi slice. The matched probe
shows that actual workspace vocabulary adds latency and regresses the short
human category for v3 and 110M. Their bare-model speed and accuracy results
therefore do not justify a default change with that vocabulary enabled.

The next multilingual research candidate remains Qwen3-ASR-0.6B through MLX,
with 8-bit and 4-bit artifacts evaluated separately if installation is later
authorized. It has not been downloaded or tested in this comparison. Moonshine
is an English streaming lead, not a Hindi solution. See the
[separate source review](asr-model-research-20261104.md) for artifact sizes,
licenses, Apple implementation evidence, and Hinglish limitations.

Before any target-hardware claim, repeat the vocabulary timing pairs,
measure the updated live path on a long speaker-playback recording, and repeat
on the M1 Air 8 GB with memory pressure and sustained use observed. Retain
human-short, negative-control, number, repetition, and per-category gates.
Passing synthetic tests and a tiny public Hindi slice cannot replace a larger
held-out natural dictation set.

Private evidence index: `release-summary.json`, `release-metadata.json`,
`release-*.jsonl`, `installed-summary.json`, `after-small-summary.json`,
`hindi-summary.json`, `hindi-fleurs/provenance.json`, `latency-summary.json`,
`latency-analysis.md`, `latency-vqe-summary.json`, `vqe-asr-comparison.json`, and
`latency-only-notes.md`, `migration-hash-memory.json`,
`final-memory-unified.jsonl`, `final-memory-unified.stderr.txt`, and
`final-memory-verify.log`. The corrected vocabulary evidence is in
`matched-vocabulary-20261103T203245Z-dcada329/`, including `metadata.json`,
`summary.json`, and the six `repeat-1-*.jsonl` outputs. Every table here is
derived from completed records.
