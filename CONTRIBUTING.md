# Contributing to Vaani

Vaani is based on BetterWispr. Read `docs/provenance.md`, preserve original authorship, and record adapted code in `docs/oss-reuse.md`. The combined derivative uses GPL-3.0-only, with retained component notices.

Use focused descriptive branches such as `fix/paste-recovery`. Keep the native architecture and explicit local/remote provider boundary. No cloud fallback, surprise model downloads, stale-session paste, or silent destructive data migration is acceptable.

Run `make test`. Use a complete compatible Xcode toolchain for Swift Testing. A toolchain failure is not a passing suite. Exercise OS behavior separately using `docs/testing.md`, and report exactly what was checked.

Keep personal settings, models, recordings, transcripts, diagnostics, credentials, and signing material out of commits. Use synthetic fixtures. Do not request a full private history in an issue. Before a release, follow `docs/maintenance.md` and include the corresponding source/build scripts and required notices.
