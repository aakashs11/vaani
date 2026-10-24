#!/bin/bash
# Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
architecture="${2:-$(uname -m)}"
if [[ $# -gt 2 || ( "$configuration" != debug && "$configuration" != release ) || ( "$architecture" != arm64 && "$architecture" != x86_64 ) ]]; then
    echo 'Usage: scripts/build-app.sh [debug|release] [arm64|x86_64]' >&2
    exit 2
fi
swift build -c "$configuration" --arch "$architecture" --product Vaani -Xswiftc -DDISABLE_APPLE_INTELLIGENCE
binary_dir="$(swift build -c "$configuration" --arch "$architecture" --show-bin-path)"
app="$binary_dir/Vaani.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
# SwiftPM checkout licenses/resources can be read-only after the first copy.
chmod -R u+w "$app"
cp "$binary_dir/Vaani" "$app/Contents/MacOS/Vaani"
cp Resources/Info.plist "$app/Contents/Info.plist"
version="$(tr -d '[:space:]' < VERSION)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" -c "Set :CFBundleVersion $version" "$app/Contents/Info.plist"
icon=.build/AppIcon.icns
iconset=.build/Vaani.iconset
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Design/vaani-icon-reference.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Design/vaani-icon-reference.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$icon"
cp "$icon" "$app/Contents/Resources/AppIcon.icns"
rm -rf "$app/Contents/Resources/Licenses" "$app/Contents/Resources/Vaani_Vaani.bundle" "$app/Contents/MacOS/FluidAudio_FluidAudio.bundle" "$app/Contents/MacOS/Vaani_Vaani.bundle" "$app/Contents/Frameworks/Sparkle.framework"
ditto "$binary_dir/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
rm -rf "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$app/Contents/Frameworks/Sparkle.framework/XPCServices"
mkdir -p "$app/Contents/Resources/Licenses"
cp LICENSE "$app/Contents/Resources/Licenses/Vaani-GPL-3.0.txt"
cp LICENSES/BetterWispr-Apache-2.0.txt "$app/Contents/Resources/Licenses/BetterWispr-Apache-2.0.txt"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/Licenses/THIRD_PARTY_NOTICES.md"
cp docs/provenance.md "$app/Contents/Resources/Licenses/Vaani-Provenance.md"
cp docs/oss-reuse.md "$app/Contents/Resources/Licenses/Upstream-Reuse.md"
cp LICENSES/Adapted-Code-Notices.txt "$app/Contents/Resources/Licenses/Adapted-Code-Notices.txt"
cp .build/checkouts/argmax-oss-swift/LICENSE "$app/Contents/Resources/Licenses/Argmax-MIT.txt"
cp .build/checkouts/argmax-oss-swift/NOTICES "$app/Contents/Resources/Licenses/Argmax-NOTICES.txt"
cp .build/checkouts/FluidAudio/LICENSE "$app/Contents/Resources/Licenses/FluidAudio-Apache-2.0.txt"
cp .build/checkouts/swift-argument-parser/LICENSE.txt "$app/Contents/Resources/Licenses/Swift-Argument-Parser-Apache-2.0.txt"
cp .build/checkouts/Sparkle/LICENSE "$app/Contents/Resources/Licenses/Sparkle-MIT.txt"
# SwiftPM resources from speech/tokenizer dependencies must travel with the app.
for resource in "$binary_dir"/*.bundle; do
    [[ -d "$resource" ]] || continue
    [[ "$(basename "$resource")" == Vaani_Vaani.bundle ]] && continue
    cp -R "$resource" "$app/Contents/Resources/"
    [[ "$(basename "$resource")" == FluidAudio_* ]] && continue
    cp -R "$resource" "$app/Contents/MacOS/"
done
identity="${CODESIGN_IDENTITY:--}"
if [[ "$identity" == - ]]; then
    echo 'Development build: ad-hoc signed. macOS permissions may need renewal after rebuilding.' >&2
fi
codesign --force --deep --sign "$identity" --entitlements Resources/Vaani.entitlements "$app"
echo "$app"
