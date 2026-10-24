# Vaani (वाणी)

Vaani is a native macOS dictation app maintained by Aakash. Hold your shortcut, speak, and release to insert text into the app you were using. Built-in speech models run locally. No account or subscription is required for local dictation.

## Origin and changes

Vaani is based on [BetterWispr](https://github.com/opennookorg/betterwispr), originally created by Kartik Labhshetwar and developed with its contributors. It retains BetterWispr's native application, model integrations, and much of its editing and meeting functionality. Original authorship and third-party acknowledgements are preserved.

Vaani adds a separate product identity, Fn/Globe and Right Command shortcuts, legacy history/vocabulary import tooling, bounded diagnostics, optional saved-recording review, history pagination, capture-startup safeguards, and more conservative vocabulary handling. The rebrand coordinates executable names, packaging, storage migration, and owner-controlled release configuration.

The [origin and changes table](docs/provenance.md) explains inherited features and Vaani modifications in detail. Vaani uses existing Whisper and NVIDIA Parakeet models through WhisperKit and FluidAudio. It does not claim to have trained a new model or proven higher recognition accuracy.

## Build and run

Requires a compatible macOS development toolchain with Swift 6.2 or later. The package targets macOS 14+, with Apple Silicon as the initial release target. Actual model availability depends on hardware and language. Full Swift tests use the toolchain’s Swift Testing framework. `make test` includes a compatibility wrapper for the installed Command Line Tools.

```sh
git clone https://github.com/aakashs11/vaani.git
cd vaani
make build
make run
```

`bash scripts/build-app.sh release arm64` creates a development bundle and prints its path. Build products live under `.build`. Development bundles use ad-hoc signing unless `CODESIGN_IDENTITY` is explicitly supplied, so macOS may require renewed permissions after a rebuild. Do not disable Gatekeeper. A public notarized download is a separate release milestone and is not implied by a successful source build.

The current build disables optional Apple Intelligence meeting notes at compile time for compatibility with the available toolchain. Local speech recognition and other explicitly selected notes providers remain available.

## First use

1. Open Vaani, grant Microphone access, and grant Accessibility access for automatic insertion. Apple speech also needs Speech Recognition permission.
2. Install a speech model explicitly in Models. Model files use local storage and retain their publisher's terms.
3. Choose your dictation shortcut in Settings. Right Command and Fn/Globe are supported. For Fn/Globe, set macOS “Press Globe key to” to “Do Nothing.” Existing installations retain their saved shortcut.
4. Hold the shortcut and wait for the recording bars before speaking. Release to finish. A quick tap can start hands-free recording and another tap finishes it. Escape cancels.

Recognition can mishear words, names, numbers, and the opening of speech. Review consequential text before using it. With the microphone off between dictations, audio spoken before hardware activation cannot be recovered.

## Existing BetterWispr installations

Vaani copies and validates legacy app-owned data into `~/Library/Application Support/Vaani` before opening its stores. It preserves the original folder, settings, IDs, history, vocabulary, models, meetings, and saved-recording references. Existing model markers remain compatible. If both folders conflict or validation fails, Vaani stops with a recovery message instead of creating an empty replacement workspace. It never silently merges unrelated folders.

The new bundle identity is `io.github.aakashs11.vaani`. macOS may require permission renewal. Legacy API credentials are copied through Keychain on first use, with original entries retained. See [migration and recovery](docs/maintenance.md).

## Privacy and support

Local models do not upload audio. An explicitly selected remote speech provider receives audio, and an explicitly selected remote editing/notes provider receives relevant text and enabled context. There is no automatic cloud fallback.

History is local and unencrypted. Saved recordings are optional. When enabled, Vaani keeps recent recordings plus pinned examples. Pins remain until deleted. Diagnostics contain bounded event/timing metadata rather than audio or transcript text. Read the [privacy details](docs/privacy.md).

Report Vaani issues in [this repository](https://github.com/aakashs11/vaani/issues). Include your app version, macOS version, model, approximate failure time, and redacted details. Do not attach your complete workspace, private recordings, credentials, or transcript archive. Automatic upstream binary updates are disabled so they cannot replace Vaani customizations.

## Development and licenses

Run `make test` for build, Swift tests, and focused preservation/packaging checks. See [testing](docs/testing.md), [architecture](docs/architecture.md), and [contributing](CONTRIBUTING.md).

The combined Vaani derivative uses [GPL-3.0-only](LICENSE), reflecting retained GPL-derived adaptations. Original BetterWispr code retains its [Apache-2.0 license](LICENSES/BetterWispr-Apache-2.0.txt). Other components and model weights retain their own terms. See [third-party notices](THIRD_PARTY_NOTICES.md) and the [detailed upstream reuse ledger](docs/oss-reuse.md). The app bundles readable license and provenance files.
