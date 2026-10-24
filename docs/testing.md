# Testing Vaani

Automated checks and physical Mac checks establish different things. A successful compile does not prove permissions, actual dictation, paste, or Spotlight behavior.

## Automated checks

Run `make test` with a complete compatible Xcode toolchain. It runs Swift build/tests, transcript/meeting evaluator checks, release preflight checks, migration fixtures, saved-evidence/vocabulary checks, and capture checks. The package requires Swift 6.2+. Optional Apple Intelligence notes are disabled in the current build configuration.

The installed Command Line Tools can compile the app but lack a discoverable complete Swift Testing setup. On that toolchain, do not report `swift test` as passing. CI uses the complete Xcode toolchain on the `macos-26` Apple Silicon runner.

Focused checks against production code are available independently:

```sh
swift build -Xswiftc -DDISABLE_APPLE_INTELLIGENCE
python3 scripts/check-identity-migration.py
bash scripts/check-dictation-evidence.sh
python3 scripts/check-microphone-startup.py
python3 Tests/evaluate_check.py
python3 Tests/release_check.py
```

`python3 scripts/check-credential-migration.py` additionally exercises a disposable Keychain account with a random UUID and synthetic secret. It does not read existing credentials. It checks lazy copying, preservation of the original entry during migration, and explicit removal without resurrection. Run it only on a Mac where Keychain is available.

Migration fixtures cover source preservation, exact settings/history, cached bytes, saved audio/pins/references, repeat launch, later Vaani edits, diverged legacy data, unrelated destination, corrupt/unsupported workspace, missing audio, and write failure. Evidence tests cover retention, pinning, corruption, interrupted saves, deletion, cancellation, and vocabulary safety. Capture checks cover stopped preparation, subscriber lifecycle, cancellation, and first-buffer delivery at 16/48 kHz.

## Candidate bundle

```sh
bash scripts/build-app.sh release arm64
python3 Tests/branding_check.py .build/arm64-apple-macosx/release/Vaani.app
codesign --verify --deep --strict .build/arm64-apple-macosx/release/Vaani.app
```

Inspect the extracted distribution, not only the build folder. Check identity, executable, dependency resources, icon, permission descriptions, bundled licenses, absence of upstream update-feed metadata, and absence of workspace/audio/credential files. An ad-hoc development signature is not Developer ID notarization.

## Physical Mac release checklist

- [ ] Finish recording, back up the installed app and all data, then install the candidate once.
- [ ] Confirm startup migration preserves settings, selected model, shortcut, history, vocabulary, meetings, evidence audio, pins, and reference text. Compare IDs and binary hashes privately. Restart once and confirm no duplicate import.
- [ ] Renew required Microphone, Accessibility, optional Speech Recognition, and Login Items authorization through macOS. Do not bypass authentication or change unrelated privacy settings.
- [ ] Exercise physical Right Command hold/release, quick-tap hands-free mode, Fn/Globe as an alternative, and Escape cancellation. Keep the user's saved shortcut selection afterward.
- [ ] Dictate into a second app and verify paste and clipboard safeguards. Cancel during capture and recognition and confirm no stale paste.
- [ ] Confirm silence and microphone-off state while idle and after cancellation. `python3 scripts/check-microphone-startup.py --activity` reads active recording bundle IDs through Core Audio.
- [ ] Check sleep/wake, reconnecting a microphone, and changing input devices without losing the prepared capture lifecycle.
- [ ] Check Finder/Dock/menu-bar artwork, Vaani titles/permission descriptions, About credits, license access, and owner-controlled source/issues links.
- [ ] Search Spotlight for `Vaani`, `vaan`, and `वाणी`, confirming the actual installed app result.
- [ ] Use a synthetic/public sample with an installed local model under network denial. Verify no fallback/upload and no automatic model download.
- [ ] Keep the previous app and original data recoverable. Record exactly which hardware checks were performed and which remain pending.

Historical upstream results are retained separately in [BetterWispr's validation snapshot](upstream/betterwispr-testing.md). They are not evidence of a current Vaani pass.
