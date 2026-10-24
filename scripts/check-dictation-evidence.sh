#!/bin/bash
# Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/evidence-check
common=(-swift-version 6 -enable-bare-slash-regex -module-cache-path .build/evidence-module-cache -parse-as-library)
swiftc "${common[@]}" Sources/VaaniCore/Domain/Transcript.swift Sources/VaaniCore/Speech/RecognitionDetails.swift Sources/VaaniCore/Storage/DictationEvidenceStore.swift Tests/EvidenceStoreCheck.swift -o .build/evidence-check/store
.build/evidence-check/store
swiftc "${common[@]}" Sources/VaaniCore/Domain/Transcript.swift Sources/VaaniCore/Transcription/CorrectionLearner.swift Sources/VaaniCore/Transcription/VocabularyProcessor.swift Sources/VaaniCore/Transcription/VoiceCommands.swift Sources/VaaniCore/Transcription/SpokenNumbers.swift Tests/VocabularySafetyCheck.swift -o .build/evidence-check/vocabulary
.build/evidence-check/vocabulary
