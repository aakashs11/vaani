# Local dictation benchmark

`scripts/benchmark_dictation.py` scores saved `VaaniCLI --bench` JSONL output
without model inference, network access, or third-party Python packages. It
reuses the existing transcript normalizer and WER/CER scorer. This tooling is
not evidence of an accuracy improvement or a measurement on an M1 Air.

Keep the recordings, references, manifests, and results outside Git. Maintain a
local JSONL manifest with one object per clip. The following is a schema example,
not a verified recording or a ready-to-run corpus:

```json
{"id":"clip-001","audio":"/absolute/private/clip-001.wav","language":"en","reference":"Send the draft tomorrow","reference_verified":true,"reference_source":"Human listened and transcribed, review date and reviewer recorded locally","duration_seconds":3.2,"category":"short-dictation"}
```

Set `reference_verified` only after checking the reference against the audio.
Keep the original human confirmation provenance. For deterministic synthetic
fixtures, record the generation method and known source text in
`reference_source`, and use a distinct category. They test controlled behavior,
not natural dictation accuracy. Annotate actual silence with an empty reference.
Do not use an unreviewed recognizer output as ground truth. The scorer validates
the verification annotation but cannot independently establish its truth.

Use stable IDs and the same manifest for both builds. The CLI accepts the extra
manifest fields and emits its existing `id`, `reference`, `hypothesis`, and
`seconds` fields. It optionally emits `cleaned` and `cleanupSeconds`. Capture
runs using an already installed model and separately record the revision, model,
decoding settings, hardware, OS, warmup state, and peak memory. No model download
is needed by this scorer. A file benchmark does not measure microphone capture,
release-to-paste latency, permissions, or the complete live app path.

```sh
python3 scripts/benchmark_dictation.py /private/corpus/manifest.jsonl /private/corpus/baseline.jsonl
python3 scripts/benchmark_dictation.py /private/corpus/manifest.jsonl /private/corpus/baseline.jsonl --candidate /private/corpus/candidate.jsonl > /private/corpus/comparison.json
python3 scripts/benchmark_dictation.py /private/corpus/manifest.jsonl /private/corpus/baseline.jsonl --candidate /private/corpus/candidate.jsonl --text-field cleaned > /private/corpus/cleaned-comparison.json
python3 Tests/benchmark_dictation_check.py
python3 Tests/evaluate_check.py
```

Reports include overall, category, and duration groups (up to 1 second, over 1 through 5 seconds, over 5
through 15 seconds, and over 15 seconds). Exact phrase match is normalized
whole-utterance equality among speech clips. Empty speech rate counts speech
clips with blank output. False speech rate counts annotated silence with any
non-whitespace output, including punctuation. Undefined rates are `null`.
WER includes insertions on silence. Substitutions, deletions and insertions use
minimum-cost word alignment, with ties favoring substitution, deletion, then
insertion. Equally optimal alignments can attribute errors differently.

Latency uses nearest-rank p50/p95 of the CLI's `seconds` field. Cleaned mode adds
`cleanupSeconds`, and requires both cleanup fields for every clip. Each run must
contain exactly the manifest IDs, unique once each, with unchanged references
and finite positive transcription times. Repeat runs in separate result files,
alternate baseline and candidate order, and report run variability and sample
counts. Tiny pilots cannot establish reliable p95 or population accuracy.

Comparisons report candidate-minus-baseline metric deltas and paired clip error
and latency deltas. The latency gate passes only when both p50 and p95 are at
most 1.10 times baseline. The accuracy gate requires no increase in total word errors or silent clips
with output, both overall and within every category. This prevents a small
category regression from being hidden by aggregate improvement.
`accuracy_improved` is true only when that gate passes and at least one of those
overall counts decreases. Equal accuracy can therefore pass for a memory fix.
Exit code 2 means either accuracy or latency failed, 1 means invalid input, and
0 means scoring succeeded and all applicable gates passed. A passing gate
does not authorize a model/default change. Review
category regressions, false speech, empty speech, names, numbers and boundaries
before accepting changes. Measure on the target M1 Air with 8 GB RAM before
making claims for it.

## Initial pilot — November 4, 2026

The private pilot contains two human-confirmed recordings and 51 existing
synthetic acoustic fixtures. It is a regression smoke test, not a representative
accuracy benchmark. No audio or private transcripts are committed.

The baseline and candidate produced identical raw and cleaned transcripts.
An isolated candidate run passed both the category accuracy gate and the 10%
latency gate: recognition p50 was 2.4% higher and p95 was 0.9% lower. Baseline
peak RSS was 1,368,752,128 bytes and isolated candidate peak RSS was
1,375,027,200 bytes, about 1.28 GiB each. A candidate run overlapping build work
reported 1,977,630,720 bytes; retain that observation rather than treating one
run as a guaranteed memory ceiling.

Measurements used the debug CLI, Parakeet Unified, and an M4 Pro with 48 GiB RAM.
They exclude microphone capture, speaker enhancement, UI, and paste. They do
not establish M1 MacBook Air 8 GiB performance or an overall accuracy increase.
The original confirmed short-phrase recognition failure remains in the pilot.

The candidate makes two small resource/correctness changes: vocabulary CTC
models load only when eligible hints need them and are released on recognizer
replacement; microphone startup resolves the current device/format before
reusing prepared capture. Neither adds a model or dependency. This pilot preceded
installation. The consolidated candidate has since been installed and exercised.
See the [current checkpoint](dictation-update-20261104.md) for its status.

## Routine validation

Run `make verify` for the full local gate, or `make evals` to repeat inference
without the unit checks. `make run`, `make dev`, `make release`, and `make ship` require
verification. Low-level build scripts only build candidates. CI runs `make test`,
including scorer and runner integration tests, but has no private corpus/model
access and therefore cannot establish a real inference pass.

Register every reviewed local suite in ignored `local/evals.json`:

```json
{"suites":[{"name":"short-dictation","manifest":"corpus/manifest.jsonl","baseline":"corpus/baseline.jsonl","model":"parakeet-unified","language":"en","cleanup":"light"}]}
```

Paths resolve relative to the config file. Override with `EVAL_CONFIG=/path/config.json`.
Each suite runs fresh CLI inference sequentially, with no model download. Light
cleanup always scores both raw and cleaned output. Missing assets, invalid
references, CLI failures, accuracy regressions, or p50/p95 regressions above 10%
fail validation. Later suites still run after an individual suite fails.

Results go to a new `local/eval-runs/<timestamp>` directory. Override with
`EVAL_OUTPUT=/path/new-directory`; existing directories are refused. `report.json`
contains all suite results, commands, model settings, file hashes and process wall
time. Per-clip latency excludes model loading, while process wall time includes
startup. Neither measures release-to-paste latency. Do not run builds or other
inference concurrently when measuring latency.

Create baselines explicitly using the same CLI settings and hardware. Preserve
historical results and document any baseline change. A new suite calibrated on
the current revision establishes future regression coverage, not evidence that
the revision improved accuracy. Do not turn diagnostic replay manifests with
unknown or empty speech references into silence tests. Do not automatically
register every JSONL file as ground truth.

The initial private registry had three suites: the 53-clip pilot, 20 recovered
scripted recordings, and 62 synthetic fixtures. The scripted references preserve
the user's confirmation that the script was read as written. They have not been
independently re-transcribed, and their prior development/holdout split has
already been examined. Synthetic variants share ten source phrases. Neither the
135-clip total nor the old split represents an independent held-out sample.
The two recovered suites were calibrated on the current candidate for future
regression checks. The pilot retains its earlier baseline.

## Short-phrase investigation — November 4, 2026

Ten additional short recordings are now registered locally, bringing the registry
to four suites and 145 clips. Unlabelled failed attempts remain replay material
and are not scored as silence. Intended speech is not automatically the reference
for file recognition: the user listened to one omitted-name recording and
confirmed the name was absent from the audio, then clarified that they had
released the shortcut before the name. This is expected stop behavior. That file's reference contains only
the audible words, with the intended phrase retained as capture evidence. A
second similar recording is excluded pending listening verification. A controlled
recording held through the final word was recognized correctly and is included.

Three experimental approaches were rejected rather than enabled: an 80 Hz
high-pass filter did not repair the original failure, no-reference use of the
installed cleanup model did not repair it and added processing time, and 160 ms
of trailing silence did not recover the names. The latter also changed a correct
short command into a different word. No overall accuracy improvement is claimed.
The original complete short-phrase failure and a name confusion remain unresolved.

Preserve floating-point samples in audio experiments. Several native CAF files
contain values above +/-1, including successful controls. Converting these to
PCM16 clips them and is not a transparent replay. The rejected trailing-context
experiment was repeated with floating-point WAVs whose unmodified controls
matched the original CAF transcriptions. No experimental preprocessing was
added to production and no model was downloaded.

## November 4 model and cleanup comparison

The installed-model comparison covers all 145 registered English clips, with two
sequential fresh-process passes in reversed model order. The approved 110M and
Whisper Small installations are evaluated separately using the same inputs.
Use the detailed comparison report for natural/synthetic categories, timing
ranges, memory, and known normalization limitations. A lower aggregate WER does
not by itself authorize changing the default. Vocabulary-enabled probes are
separate because v3/110M can load an additional CTC model for user hints.

The repetition compatibility patch has a pure token regression and an audio
regression: it restores the first word of an intentionally repeated affirmation
in the scripted set. It does not change model weights or add an inference pass.

The cleanup compute-unit experiment uses 54 paired synthetic fixtures, including
three repeated long stress recordings. CPU/GPU comparisons preserve Float32
audio, check sample differences, and score both results. These fixtures test
numerical and recognition regressions, not actual microphone-to-paste latency.
Saved live event timings are reported separately. No M1 Air measurement is implied.
