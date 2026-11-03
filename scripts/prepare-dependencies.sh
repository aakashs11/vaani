#!/bin/bash
# Apply the reviewed fix to the pinned dependency before canonical builds.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d .build/checkouts/FluidAudio ]]; then
    swift package resolve
fi
python3 scripts/apply-fluidaudio-patch.py
