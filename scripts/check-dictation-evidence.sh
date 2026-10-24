#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/evidence-check
common=(-swift-version 6 -enable-bare-slash-regex -module-cache-path .build/evidence-module-cache -parse-as-library)
swiftc "${common[@]}" Sources/BetterWisprCore/Domain/Transcript.swift Sources/BetterWisprCore/Speech/RecognitionDetails.swift Sources/BetterWisprCore/Storage/DictationEvidenceStore.swift Tests/EvidenceStoreCheck.swift -o .build/evidence-check/store
.build/evidence-check/store
swiftc "${common[@]}" Sources/BetterWisprCore/Domain/Transcript.swift Sources/BetterWisprCore/Transcription/CorrectionLearner.swift Sources/BetterWisprCore/Transcription/VocabularyProcessor.swift Sources/BetterWisprCore/Transcription/VoiceCommands.swift Sources/BetterWisprCore/Transcription/SpokenNumbers.swift Tests/VocabularySafetyCheck.swift -o .build/evidence-check/vocabulary
.build/evidence-check/vocabulary
