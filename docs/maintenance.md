# Maintenance and recovery

Vaani keeps BetterWispr as an attributable upstream foundation. Its base commit is recorded in `provenance.md`. Review upstream source changes and cherry-pick them onto a focused branch. Do not install BetterWispr binary updates over Vaani.

## Commands

- `make build` builds the local app bundle.
- `make run` builds and launches it. Finish any active recording first.
- `make test` runs build, Swift tests, evaluator checks, release preflight checks, migration fixtures, evidence/vocabulary checks, and capture checks.
- `bash scripts/build-app.sh release arm64` builds an Apple Silicon development bundle.
- `bash scripts/export-diagnostics.sh` creates an ignored local diagnostics export for review.

Models and tokenizers download only after an explicit user installation. Keep dependency versions pinned. Model terms are separate from library terms. Never commit model weights, recordings, workspace databases, signing keys, or private diagnostics.

## Identity migration

Startup validates and copies `~/Library/Application Support/BetterWispr` into a staged sibling folder, then atomically activates `Vaani`. A private `.vaani-migration.json` receipt records source file hashes. Original IDs, settings, transcript text, models, and recording bytes are preserved. Existing model installation markers remain valid. A repeated migration recognizes the receipt and permits later edits made by Vaani.

If the legacy folder changes after migration or a populated destination has no matching receipt, Vaani preserves both and stops. Do not delete a folder or the receipt to bypass the check. Back up both, compare the workspaces, and recover the intended version with the app closed. There is no automatic conflicting-data merge.

If migration fails, the old installation remains recoverable. Quit Vaani before restoring any backup. Restore the previous app and its matching legacy data copy together. Preserve the newer Vaani folder separately until you verify recovery. Never overwrite the only copy of newer dictations.

A changed bundle/signing identity can require Microphone, Speech Recognition, Accessibility, and Login Items authorization. If Accessibility appears enabled but paste fails, remove the stale entry and add the current installed Vaani app. macOS authentication remains a user action. The shortcut setting and recording-retention choices are preserved.

## Releases

`make ship` requires owner-supplied `SIGNING_IDENTITY`, `APPLE_TEAM_ID`, and `NOTARY_PROFILE`. `make setup-notary` saves credentials through Apple's secure prompt. No upstream developer identity is assumed. Release staging preserves previous artifacts on failure. Only a successfully signed, notarized, stapled, and assessed artifact may be described as notarized. Development artifacts are ad-hoc signed and are not a substitute.

Before publishing, run the CI checks, inspect the extracted bundle and license folder, exercise the physical Mac checklist in `testing.md`, and verify links. Supply the corresponding source and build scripts for each distributed GPL-covered binary. No automatic update feed is configured. Do not enable one without owner-controlled signing keys and a separately reviewed update design.
