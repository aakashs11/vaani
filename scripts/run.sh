#!/bin/bash
# Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh "${1:-debug}"
open ".build/${1:-debug}/Vaani.app"
