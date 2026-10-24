# Vaani origin and changes

Vaani (वाणी) is maintained by Aakash. It is based on [BetterWispr](https://github.com/opennookorg/betterwispr), originally created by Kartik Labhshetwar and developed with its contributors. The source history is preserved. The Vaani starting point is commit `c10b57fd9525216045ab7e9e35d851bacca5cfe7`.

Vaani retains the upstream speech engines and native application foundation. Its changes focus on branding, shortcuts, migration, diagnostics, recording review, and everyday usability. Original authorship and third-party acknowledgements are preserved. This is an independently maintained derivative, with no claim of upstream endorsement.

| Area | Origin and Vaani changes |
| --- | --- |
| Native SwiftUI/AppKit application, local recognition, model selection, editing modes, meetings | Inherited from BetterWispr and its credited dependencies. |
| Whisper/WhisperKit and NVIDIA Parakeet/FluidAudio | Existing models and inference engines. Vaani has not trained a new recognition model. Model licenses are separate from engine licenses. |
| Identity | Vaani name, existing purple artwork integration, English app discovery, package/module/executable names, installer metadata, and owner-controlled release configuration. |
| Shortcuts | Fn/Globe and Right Command support. Existing user selection is preserved. |
| History | Legacy transcript/vocabulary import tooling and bounded history rendering. No private imported databases or recordings are distributed. |
| Diagnostics | Bounded local timing logs without transcript/audio contents, plus private diagnostic export tooling. |
| Recording review | Optional recent audio retention, playback, pinning, reviewed references, and distinct recognizer/final text. |
| Capture | Stopped-queue preparation, first-buffer handling, and cancellation safeguards, with the microphone off between dictations. No accuracy improvement is claimed. |
| Vocabulary | More conservative learning and speech hints. General phrase replacements are not a substitute for recognition evaluation. |
| Identity migration | Validated copy with source hashes, conflict detection, retained original data, and lazy Keychain credential migration. |

## License decision

The combined Vaani derivative is distributed under GPL-3.0-only because the retained source includes GPL-3.0 adaptations documented in the inherited reuse ledger. No undocumented alternative permission is assumed. Original BetterWispr code retains its Apache-2.0 notices, whose full license is in `LICENSES/BetterWispr-Apache-2.0.txt`. Permissive dependencies and adapted code keep their original terms. See `LICENSE`, `THIRD_PARTY_NOTICES.md`, and `docs/oss-reuse.md`. Source for this derivative, including modifications and build scripts, accompanies source releases.

## Assets and development

The purple icon was generated for Vaani during an earlier AI-assisted design session at Aakash's request. That session developed the Devanagari आ, waveform, sky, and horizon composition. It is separate from the original BetterWispr mark. `Design/vaani-icon-reference.png` is the generated bitmap. `Design/vaani-icon-editable.svg` is its editable vector recreation, not the original source of the bitmap. These assets are included with Vaani under the project's license, subject to any applicable rights in AI-generated output. No claim of exclusive trademark rights is made.

Development and review were AI-assisted. Build results and hardware checks are reported separately. Vaani does not claim independently measured recognition accuracy or a newly trained model.

## Upstream maintenance

Keep BetterWispr as the `upstream` remote. Review and cherry-pick changes into Vaani rather than applying upstream binary updates. Compatibility readers retain old names for saved model installation markers and legacy credentials. Historical BetterWispr changelog entries remain attributed to upstream.
