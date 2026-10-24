#!/bin/bash
# Vaani addition, 2026: run the same suite with full Xcode or the CLT Testing framework.
set -euo pipefail
cd "$(dirname "$0")/.."
arguments=(-Xswiftc -DDISABLE_APPLE_INTELLIGENCE)
developer="$(xcode-select -p)"
frameworks="$developer/Library/Developer/Frameworks"
if [[ "$developer" == */CommandLineTools && -d "$frameworks/Testing.framework" ]]; then
    # CLT omits the Foundation overlay module. Tests use the core Testing APIs.
    arguments+=(-Xswiftc -F -Xswiftc "$frameworks" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays
                -Xlinker -F -Xlinker "$frameworks" -Xlinker -rpath -Xlinker "$frameworks")
fi
exec swift test "${arguments[@]}" "$@"
