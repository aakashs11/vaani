# Third-party notices

Vaani is an independently maintained derivative of BetterWispr, originally created by Kartik Labhshetwar and contributors. BetterWispr base: `c10b57fd9525216045ab7e9e35d851bacca5cfe7`. Vaani modifications: Aakash, 2026. Combined derivative: GPL-3.0-only. Original notices remain applicable to their respective portions.

| Component | License and use |
| --- | --- |
| BetterWispr | Apache-2.0. Native application and recognition foundation. Full original license in `LICENSES/BetterWispr-Apache-2.0.txt`. |
| VoiceInk, revision `c09cc1f677f40f2ee665843a61f07670210f012e` | GPL-3.0. Adapted preview, correction, warm-up, editing/context, and writing-mode logic. See inherited reuse ledger for exact files and changes. |
| Argmax OSS / WhisperKit 1.1.0 | MIT, copyright 2024 argmax, inc. Inference dependency and adapted local tokenizer. Dependency license and notices ship in the app. |
| FluidAudio 0.17.5 | Apache-2.0. Parakeet inference and speaker detection, including adapted parameter parsing. |
| FluidAudio bundled third-party code | Its `ThirdPartyLicenses` directory ships intact, including NemoTextProcessing/Rust FST dependencies, fastcluster, VBx, and text frontend notices. |
| Sparkle 2.10.0 | MIT. Retained dependency scaffolding, with upstream automatic updates disabled and no upstream feed/key configured. |
| Swift Argument Parser 1.8.2 | Apache-2.0. Transitive dependency. |
| BetterShot | BSD-3-Clause, copyright 2026 Kartik Labhshetwar. Adapted toast surface and original release-workflow reference. |
| Scribe | MIT. Adapted spoken commands. |
| OpenWhispr | MIT, copyright 2024 OpenWhispr Team. Adapted correction learner. |
| Muesli | MIT, copyright 2026 Pranav Hari. Adapted Core Audio process tap. |
| AudioCap | BSD-2-Clause, copyright 2024 Guilherme Rambo. Adapted process tap. |

Full adapted-code notices are in `LICENSES/Adapted-Code-Notices.txt` and the app's `Contents/Resources/Licenses` folder. Detailed upstream sources, revisions, and adaptation descriptions remain in `docs/oss-reuse.md`. Its historical `Sources/BetterWispr*` paths map to `Sources/Vaani*`. Website-only components are absent from Vaani releases, with original source retained in upstream history.

Model weights are not bundled. NVIDIA Parakeet weights and their FluidInference conversions retain their own model-card attribution and license terms, including CC-BY-4.0 where specified. Whisper weights retain their publisher's MIT terms. Optional speaker-detection weights have separate terms. Installation is an explicit user action. See the linked model cards in `docs/oss-reuse.md`; inference-library licensing does not replace weight licensing.
