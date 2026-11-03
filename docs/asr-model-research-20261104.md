# Small local ASR candidates for Vaani

Research date: **2026-11-04**. Target: an M1 MacBook Air with 8 GB unified memory,
English, Hindi, and Hindi–English code-switching. This is a source review, not a
benchmark. No models were downloaded, converted, installed, or run for this
research. Linked pages were checked on the research date. Mutable model cards
and repositories should be pinned to revisions before a later experiment.

## What is worth evaluating

The best next multilingual candidate to investigate is **Qwen3-ASR-0.6B through
MLX**, with its existing Swift implementation as the integration lead. **Whisper
small multilingual** remains the simpler established comparison. **Moonshine
Streaming Small** is a credible English-only latency experiment. **IndicConformer
Hindi** is a smaller Hindi-specialist experiment whose Apple integration and
English-word behavior need substantially more validation. These are priorities
for controlled tests, not recommendations to replace the installed default.
The evidence supporting each choice and its limits follows below.

For this app, a useful model must preserve one-word commands, names, numbers,
negation, and language switches, then finish quickly after release. Published
read-speech WER or server throughput alone cannot decide that. Hindi support
means the model accepts Hindi speech. It does not establish correct Hinglish
recognition, retention of English words in Latin script, Romanized Hindi output,
or reliable language identification on a one-second utterance.

## Size and implementation comparison

Download size, parameter count, and runtime memory are different measurements.
The table preserves the units reported by its sources. Runtime memory includes
weights, activations, decoder state, temporary buffers, backend caches, and
other app components. A quantized file's size is not a peak RAM measurement.
None of the numbers below is a new Vaani measurement on an M1 Air.

| Candidate | Parameters / artifact evidence | Language scope relevant here | Apple implementation evidence | Initial disposition |
| --- | --- | --- | --- | --- |
| Whisper tiny / base / small multilingual | 39M / 74M / 244M. whisper.cpp lists 75 / 142 / 466 MiB disk and about 273 / 388 / 852 MB memory for its builds. | English and Hindi through multilingual checkpoints. `.en` checkpoints are English-only. | WhisperKit/Core ML, whisper.cpp/Metal/Core ML, and MLX implementations exist. | Keep small as the established multilingual comparison. Tiny/base establish the accuracy floor at lower compute. |
| Qwen3-ASR-0.6B | Product name is 0.6B, but upstream HF reports **0.9B total** and a 1.88 GB BF16 weight file. MLX 4-bit tree lists 713 MB total, including 708 MB weights. | English and Hindi are explicitly listed. Hinglish requires direct tests. | Python MLX and Swift MLX implementations list the 0.6B model and quantizations. | Most relevant new multilingual architecture to benchmark. |
| Moonshine Streaming Tiny / Small / Medium | 34M / 123M / 245M. These are parameter counts, not download sizes or measured RAM. | Current official availability list has English and several other languages, **no Hindi**. | On-device toolkit explicitly supports macOS and Apple integration. | English latency candidate, not the Hindi solution. |
| IndicConformer Hindi | Card describes a 120M-parameter encoder with hybrid CTC/RNNT decoding. Official `.nemo` artifact is 523 MB. | Hindi specialist. Mixed English retention is unproven. | Official example is AI4Bharat NeMo with CPU/CUDA selection. ONNX/sherpa is a possible porting route. | Lower-size Hindi experiment after conversion/parity validation. |
| IndicConformer multilingual | 600M, hybrid CTC/RNNT. Do not infer full artifact size from parameter count. | 22 Indian languages including Hindi. English is absent from the published list. | Official ONNX/custom-code wrapper exists. No target-Mac latency or RAM result established here. | Less direct fit for English/Hinglish than the language list may imply. |
| Vosk small Hindi | Catalog lists **42 MB download**, not 42M parameters. Small-model runtime guidance is roughly 300 MB, not a per-Hindi M1 measurement. | Hindi model, separate English model available. | Lightweight offline CPU deployment is its intended use. Native app integration still needs validation. | Resource-floor comparison, not presumed dictation quality winner. |
| Meta omniASR-CTC-300M | 325,494,996 parameters, 1.3 GiB FP32 download. Published ~2 GiB inference VRAM is BF16/A100, batch 1, 30-second audio. | Broad multilingual family. Verify exact language/script IDs and Hinglish behavior. | fairseq2 reference stack mentions Mac setup. No production Swift or M1 result established here. | Research reserve behind models with clearer Apple deployment. |

Table sources: [OpenAI Whisper sizes and license](https://github.com/openai/whisper),
[whisper.cpp memory and Apple backends](https://github.com/ggml-org/whisper.cpp),
[Qwen upstream card](https://huggingface.co/Qwen/Qwen3-ASR-0.6B),
[Qwen original files](https://huggingface.co/Qwen/Qwen3-ASR-0.6B/tree/main),
[MLX 4-bit files](https://huggingface.co/mlx-community/Qwen3-ASR-0.6B-4bit/tree/main),
[Moonshine available models](https://github.com/moonshine-ai/moonshine/blob/main/docs/models/available-models.md),
[IndicConformer Hindi card](https://huggingface.co/ai4bharat/indicconformer_stt_hi_hybrid_ctc_rnnt_large),
[Hindi artifact listing](https://huggingface.co/ai4bharat/indicconformer_stt_hi_hybrid_ctc_rnnt_large/tree/main),
[IndicConformer multilingual card](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual),
[Vosk catalog](https://alphacephei.com/vosk/models),
[Meta model specifications](https://huggingface.co/facebook/omniASR-CTC-300M).

## Concrete artifacts for a later authorized experiment

These artifacts were not downloaded in this source review. The separately
authorized Whisper Small and Parakeet 110M experiments are documented in the
local comparison report.

| Artifact | Published download/file size | Compatibility caveat |
| --- | --- | --- |
| [`mlx-community/Qwen3-ASR-0.6B-8bit`](https://huggingface.co/mlx-community/Qwen3-ASR-0.6B-8bit/tree/89e96d92ba34aca20b3e29fb10cc284097d1219f) | 1.01 GB at revision `89e96d92ba34aca20b3e29fb10cc284097d1219f` | Listed by the Swift MLX implementation. Best initial precision comparison. |
| [`mlx-community/Qwen3-ASR-0.6B-4bit`](https://huggingface.co/mlx-community/Qwen3-ASR-0.6B-4bit/tree/main) | 713 MB repository, 708 MB weights | Listed by Swift MLX. Score separately from 8-bit. |
| [`moona3k/mlx-qwen3-asr-0.6b-4bit`](https://huggingface.co/moona3k/mlx-qwen3-asr-0.6b-4bit) | Card says 517M, HF artifact display says 538 MB | Mixed 4-bit decoder/8-bit encoder, custom loader at least 0.4.3. Do not assume Swift loader interchangeability. |
| [`moona3k/mlx-qwen3-asr-0.6b-8bit`](https://huggingface.co/moona3k/mlx-qwen3-asr-0.6b-8bit) | Card says 801M, HF artifact display says 836 MB | Same implementation's higher-precision comparison. Resolve size-unit discrepancy with exact bytes when installing. |
| [`moonshine-ai/moonshine-streaming-small`](https://huggingface.co/moonshine-ai/moonshine-streaming-small/tree/main) | 562 MB repository, 561 MB safetensors weights | Reference artifact. The native toolkit uses its own ORT-format artifacts, so this is not the native runtime download total. |
| [`ai4bharat/indicconformer_stt_hi_hybrid_ctc_rnnt_large`](https://huggingface.co/ai4bharat/indicconformer_stt_hi_hybrid_ctc_rnnt_large/tree/main) | 523 MB `.nemo` file | Hindi specialist requiring access acceptance and a validated deployment path. |

The smaller moona3k artifacts avoid storing a tied language-model head twice,
according to their publisher. Their English parity tests use 100 LibriSpeech
clips on an M4 Pro, not Hindi or an M1 Air. The smaller package does not establish
better app latency or equivalent Hinglish output.
[4-bit conversion details](https://huggingface.co/moona3k/mlx-qwen3-asr-0.6b-4bit),
[8-bit conversion details](https://huggingface.co/moona3k/mlx-qwen3-asr-0.6b-8bit).

## Qwen3-ASR: promising, with real integration work remaining

The January 29, 2026 technical report describes unified offline/streaming ASR
and language identification. The license is Apache-2.0. Its 92 ms first-token
and high-concurrency throughput claims are **publisher benchmark results**, not
M1 dictation completion times. First-token time also differs from final-text
time. Do not import either number into a product performance claim.
[Technical report](https://arxiv.org/abs/2601.21337).

The upstream card explicitly includes Hindi and English among 30 languages,
plus 22 Chinese dialects. Its separate forced aligner supports a smaller
language set that does not list Hindi. Do not add that extra model merely to
produce dictation text. The upstream package can automatically fetch weights
when given a Hub model name, so a future provider must load an explicit installed
local directory and preserve Vaani's no-download-on-transcription rule.
[Upstream implementation](https://github.com/QwenLM/Qwen3-ASR).

MLX Audio documents a 0.6B 8-bit loading example. Its Swift companion lists
0.6B BF16, 8-bit, 6-bit, and 4-bit variants and provides ASR and token-streaming
examples. The Swift package currently declares macOS 14 and Swift tools 6.2,
which is encouraging for this repository's platform target. This is source-level
compatibility evidence, not a successful build or proof that token streaming
incrementally consumes live microphone audio. The public example takes a whole
audio array. Audit cancellation, model lifetime, sample-rate handling, offline
loading, and concurrent calls before a provider experiment.
[Python MLX Audio](https://github.com/Blaizzy/mlx-audio),
[Swift Qwen documentation](https://github.com/Blaizzy/mlx-audio-swift/blob/main/Sources/MLXAudioSTT/Models/Qwen3ASR/README.md),
[Swift package manifest](https://github.com/Blaizzy/mlx-audio-swift/blob/main/Package.swift).

Compare quantizations as distinct candidates. A smaller file can change acoustic
accuracy, not just speed. One MLX implementation's own tests report worse results
when quantizing the audio encoder to four bits than when keeping it at eight
bits. Those results are specific to its evaluation lane and are not Hindi or
M1-Air validation. They justify retaining an 8-bit-encoder option, not claiming
a universal best quantization.
[MLX implementation's quantization discussion](https://github.com/moona3k/mlx-qwen3-asr).

The naming deserves care: some derivative cards describe approximately 0.8B
parameters while upstream HF reports 0.9B. Do not resolve this discrepancy by
assuming the 0.6B product name is the whole network. Pin the exact artifact and
inspect its tensor inventory before making precise parameter or memory claims.

## Hinglish fine-tunes: useful research leads, not established defaults

**Srota**, `moorlee/qwen3-asr-0.6b-hinglish`, is an Apache-2.0 full fine-tune
intended to retain Hindi in Devanagari and English in Latin script. Its authors
report HiACC WER improving from 24.73% to 15.85%, and OpenSLR-104 from 50.66% to
35.06%. These are their own held-out corpus results, not Vaani results. The card
explicitly discourages treating it as a production pure-Hindi or pure-English
replacement. Its documented inference path uses CUDA/BF16, so successful
conversion and mixed-script parity through the Swift MLX backend are not yet
established. This is the most directly relevant code-switching specialization
found, but it needs pure-English and short-command regression tests as well as
Hinglish tests.
[Srota publisher card](https://huggingface.co/moorlee/qwen3-asr-0.6b-hinglish).

**Orato Hindi v1** claims a calling-domain fine-tune on about 1,000 hours and has
Hindi/Hinglish tags. Its card reports gains against its base model, but comparison
with other systems mixes published results and normalization procedures. The
card also contains inconsistent FLEURS figures, 16.58 and 16.98. More materially,
its data-rights section says licensing/consent review remains in progress and
limits the release to internal/beta evaluation until that review completes.
An Apache-2.0 label does not erase that explicit caveat. It is not a shipping
candidate without resolving the publisher's terms and provenance. No Apple
runtime performance is established by its CUDA example.
[Orato publisher card](https://huggingface.co/tryorato/orato-asr-hindi-v1).

A smaller **Whisper-small Hindi fine-tune** is also worth keeping on the research
list. Zindagi's September 3, 2026 card describes 134.75 hours of Kathbath training
and reports Hindi improvements. It preserves the Whisper architecture, but its
Hindi-specific evaluation does not establish English or Hinglish retention.
The reported large base-model error rates merit reproducing the decoding and
normalization setup before accepting the claimed improvement. Its card calls
the base Apache-2.0, whereas OpenAI's repository labels Whisper code and weights
MIT. Preserve the original notices and verify the derivative's actual license
files before distribution.
[Fine-tune card](https://huggingface.co/zindagi-technologies/whisper-small-hindi),
[Whisper upstream license statement](https://github.com/openai/whisper#license).

## IndicConformer: smaller Hindi model, but language scope matters

The Hindi-specific model's 120M encoder and 523 MB checkpoint make it more
interesting for an 8 GB machine than automatically choosing the 600M
multilingual model. The official model is MIT and access-gated on Hugging Face.
The Hindi example selects either a CTC decoder or RNNT decoder, uses 16 kHz mono
audio, and depends on AI4Bharat's NeMo fork. CTC is a reasonable deployment
experiment, but decoder changes can change accuracy and must retain a separate
baseline. Neither a Hindi tokenizer nor a language argument proves handling of
English technical terms within Hindi sentences.
[Official Hindi usage](https://huggingface.co/ai4bharat/indicconformer_stt_hi_hybrid_ctc_rnnt_large).

The 600M model is also MIT and access-gated. It provides ONNX/custom-code loading
and requires a language code such as `hi` in its example. English is not one of
its 22 listed languages. Treat it as an Indic recognizer, not a demonstrated
single-model English/Hinglish replacement.
[Official multilingual usage](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual).

sherpa-onnx supports macOS, arm64, and Swift/C interfaces, which makes an ONNX
integration plausible. That platform support does not certify any particular
community IndicConformer export. A maintainer discussion describes successful
CTC integration after metadata changes while RNNT export remained problematic.
Use that as a porting lead. Audit model provenance, tokenizer IDs, metadata,
feature extraction, and exact transcription parity against the upstream model
before trusting a converted artifact.
[sherpa platform documentation](https://github.com/k2-fsa/sherpa/blob/master/docs/source/intro.rst),
[IndicConformer integration discussion](https://github.com/k2-fsa/sherpa-onnx/discussions/3199).

The current IndicConformer card recommends **Indic-Transcribe-core**, but it is
not simply a smaller MIT upgrade. Its card specifies 1.2B parameters based on
Canary, 25 languages including Indian English, and native-script output. English
words inside Indic speech are rendered in the Indic script. The publisher uses
an Indic Open Model License with conditions rather than MIT, and says the base
model's terms also apply. No validated M1 Air latency/RAM result was located.
It remains a separate higher-cost research option, not the first experiment for
this request.
[Indic-Transcribe publisher card and terms](https://huggingface.co/bodhan-ai/indic-transcribe-core).

## Moonshine: the clearest small English streaming experiment

The February 12, 2026 Moonshine v2 paper uses bounded local attention to reduce
streaming encoder work. This is architecturally relevant when final-text delay
matters, because work can happen while the person speaks. Its English model
sizes are materially below the multilingual Qwen artifact. These design facts
do not establish superiority on Vaani's short English phrases.
[Moonshine v2 paper](https://arxiv.org/abs/2602.12241).

The Streaming Small card explicitly warns that its Transformers path is not
fully efficient streaming and that hallucination/repetition remain possible on
short or noisy segments. Evaluate the native toolkit instead of assuming a
Python pipeline reproduces its streaming performance. The toolkit documents
macOS support. Its benchmark defines latency from the library's detected speech
end to delivery, which excludes any mismatch between the user's actual stop and
the endpoint detector. Vaani still needs release-to-final and release-to-paste
measurements.
[Streaming model card](https://huggingface.co/moonshine-ai/moonshine-streaming-small),
[Toolkit platforms](https://github.com/moonshine-ai/moonshine/blob/main/docs/index.md),
[Benchmark definition](https://github.com/moonshine-ai/moonshine/blob/main/docs/using/benchmarks.md).

All English and current streaming models are MIT under the project's current
license documentation. Some legacy non-English non-streaming models retain a
non-commercial license. Check the actual model, not merely the toolkit license.
The current availability list has no Hindi model, so Moonshine cannot be the
sole English/Hindi solution on the evidence reviewed.
[Model availability](https://github.com/moonshine-ai/moonshine/blob/main/docs/models/available-models.md),
[License distinctions](https://github.com/moonshine-ai/moonshine/blob/main/docs/license.md).

## Sarvam and other alternatives

**Sarvam Saaras is a hosted option, not a verified local model candidate.** The
current API docs identify `saaras:v4` as the recommended endpoint model and
expose transcription, verbatim, transliteration, and code-mixed output modes.
Those output choices are relevant to Hinglish product design. They do not imply
that downloadable weights or a local runtime exist. I found no official Saaras
or Saarika ASR weights in the public Sarvam Hugging Face inventory reviewed.
Sarvam's public text-generation and translation weights are different products.
Do not route audio to Sarvam as a fallback or describe it as open local ASR.
Its current REST endpoint caps audio at 30 seconds, so longer dictations need
a streaming or batch integration rather than simply replacing the local call.
[Sarvam ASR API and limits](https://docs.sarvam.ai/api/api-guides-tutorials/models/saaras),
[Sarvam's public model inventory](https://huggingface.co/sarvamai).

**Vosk small Hindi** is a genuine low-resource baseline with Apache-2.0 model
licensing. Its catalog reports 20.89% and 24.72% WER on two Hindi challenge sets.
Those scores are not directly comparable with Qwen/Srota numbers on different
data. Separate Hindi and English models do not by themselves provide a good
code-switching experience. The small model's size is appealing for a constrained
CPU experiment, but vocabulary and spontaneous dictation quality must decide
whether it is useful.
[Vosk model catalog](https://alphacephei.com/vosk/models).

**Meta Omnilingual CTC 300M** is Apache-2.0 and worth retaining as an alternative
non-autoregressive architecture. Do not confuse `CTC_300M` with `LLM_300M`: the
latter is listed at approximately 1.63B total parameters and 6.1 GiB download.
The reference framework added v2 checkpoints in December 2025. Its broad
language coverage and A100 memory/speed figures do not establish M1 latency,
Hinglish quality, or a ready Swift deployment. Prefer verifying the exact v2
CTC artifact and Apple execution path before an experiment.
[Meta sizes](https://huggingface.co/facebook/omniASR-CTC-300M),
[Meta implementation and v2 update](https://github.com/facebookresearch/omnilingual-asr).

**Parakeet TDT v3** is 600M with CC-BY-4.0 weights and English plus 24 other
European languages. Hindi is absent. It remains relevant to the existing English
path, but its multilingual label does not satisfy Hindi/Hinglish requirements.
[NVIDIA model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3).

**SenseVoiceSmall** specifically lists Mandarin, Cantonese, English, Japanese,
and Korean for the released small model. Its family's broader language claims
should not be applied to that checkpoint. It does not establish Hindi support.
**Voxtral Mini Realtime** is a roughly 4B-class model with a separate substantial
audio encoder and Apache-2.0 release. It is not the first small-memory candidate
here. Its configurable streaming delay is a model setting, not an M1 completion
benchmark.
[SenseVoiceSmall card](https://huggingface.co/FunAudioLLM/SenseVoiceSmall),
[Voxtral Realtime card](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602).

## Apple SpeechAnalyzer is a separate system-engine comparison

SpeechAnalyzer/SpeechTranscriber arrived with the OS 26 generation. It can be
an optional macOS 26+ comparison, while Vaani's macOS 14 target still needs its
existing compatible providers. Apple's API runs recognition on-device and
manages models through AssetInventory. It is not an open-weight model to bundle.
Its decoder runs outside the app process, so small app RSS does not mean zero
system memory consumption. Model assets may need installation, which should
remain an explicit user action.
[Apple WWDC25 session](https://developer.apple.com/videos/play/wwdc2025/277/).

Do not infer Hindi support from Siri, keyboard dictation, text-to-speech, or
another Apple feature's language list. Apple directs clients to check
`SpeechTranscriber.isAvailable` and `supportedLocales`. A target-machine check
of supported and installed locales is required. I did not establish dependable
native-script Hindi transcription on this user's Mac from Apple's static docs.
[SpeechTranscriber availability API](https://developer.apple.com/documentation/speech/speechtranscriber?changes=_11),
[supported locales API](https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocales).

Whisper Notes' own October 31, 2026 update reports Hindi rendered in English
letters and excludes its 101.50% WER from ranking. That is a useful demonstration
of script mismatch, not proof that Apple cannot recognize Hindi acoustics.
Its experiment used FLEURS read speech on **one M5 MacBook Air**, with Qwen
**1.7B**, not our proposed 0.6B model or target M1. The author explicitly describes
its speed figures as processing throughput rather than product latency. These
results motivate local comparison but cannot predict this app's performance.
[Vendor's original experiment and methodology](https://whispernotes.app/blog/apple-speech-vs-whisper).

## Reddit findings and what survived verification

A [Hinglish Whisper experiment](https://www.reddit.com/r/LocalLLM/comments/1x01c70/i_tested_whisper_on_my_own_hinglish_speech_the/)
reported testing 20 personal commands and poor larger-model behavior. This is
an anecdotal, small personal sample, not evidence that smaller Whisper models
universally win. It reinforces the need for this user's exact short phrases.
Comments suggesting a glossary or fine-tuning are experiment ideas, not verified
fixes.

A [Mac app discussion of Qwen and Apple engines](https://www.reddit.com/r/WhisperNotes/comments/1wc8itp/mac_161_two_new_engines_qwen3asr_17b_and_apple/)
explicitly cautions that its comparisons use read speech on one Mac. Independent
primary-source checks above establish Qwen's Hindi support and the availability
of an MLX implementation. They do not validate that app's timing on an M1 Air.

The [Orato announcement](https://www.reddit.com/r/speechtech/comments/1vtaww2/finetuned_qwen3asr06b_on_1000_hours_of/)
led to its actual publisher card. The card's data-rights caveat and inconsistent
FLEURS values are more important for a decision than the announcement's headline
comparison. None of these Reddit posts is used as technical proof of model
compatibility, license clearance, or a benchmark win.

## What an English/Hindi-only product scope changes

Restricting the language setting does not remove other languages' weights from
an installed multilingual model. In Vaani's current Whisper provider, language
is a decoding option applied after the same model has loaded. It can reduce
language-identification ambiguity, especially for short utterances, but it is
not a model-memory optimization by itself.

For an 8 GB target, the practical design recommendation is to load one selected
recognizer at a time. An English-specialist default plus an explicitly selected
Hindi-capable model can keep resident model count bounded. It does not solve
Hinglish within one utterance: that case needs a jointly capable recognizer and
mixed-language evaluation. Running both engines on every clip and choosing a
result would add memory and latency, and the current evidence does not justify
that approach. Pruning or fine-tuning a bilingual model is a separate training
project, not a safe configuration shortcut.

## Proposed experiment order and decision criteria

1. Establish the installed-model baseline on verified natural speech, including
   the exact reported failures. Keep English, Hindi, and Hinglish separate, with
   duration bins of up to 1 second, 1–5, 5–15, and over 15 seconds. Synthetic
   fixtures remain a separate category.
2. Compare Whisper small multilingual against the installed model using the
   existing local engine if already available. Keep language, vocabulary,
   cleanup, and decoding settings fixed. Record cold and warm runs separately.
3. When installation is explicitly authorized, evaluate Qwen3-ASR-0.6B with
   8-bit and 4-bit variants. Confirm upstream/conversion parity before deciding
   that smaller weights improve the actual app. Try Srota only as a separate
   Hinglish specialization with English/Hindi regression coverage.
4. If English release latency remains the bottleneck, benchmark Moonshine
   Streaming Small through the native toolkit. If Hindi alone remains poor,
   investigate IndicConformer Hindi CTC conversion before the larger Indic model.
5. Measure peak process memory, system memory pressure/swap, cold load, warm
   transcription, sustained repeated use, and release-to-paste on the actual
   M1 Air 8 GB. Never substitute A100 throughput, first-token latency, or model
   download size for these measurements.

Use normalized WER/CER, phrase-exact match, deletions, insertions, false speech,
empty speech, and p50/p95 latency. Keep a second explicit script/output rubric
for Hinglish. A correctly recognized English word written in Devanagari is a
rendering mismatch as well as a possible WER mismatch, while a missing negation
is a semantic error. Do not silently transliterate or LLM-rewrite both sides to
make scores improve. Preserve raw outputs and count named entities, numbers,
and negation separately.

The new local scorer's overall/per-category no-regression accuracy gate and
10% p50/p95 latency allowance are useful initial acceptance checks. A model
switch still needs a demonstrated gain on the held-out target corpus, usable
memory headroom with the rest of the app, and live-path validation. The present
research establishes candidates and exclusions only.
