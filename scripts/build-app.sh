#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
architecture="${2:-$(uname -m)}"
if [[ $# -gt 2 || ( "$configuration" != debug && "$configuration" != release ) || ( "$architecture" != arm64 && "$architecture" != x86_64 ) ]]; then
    echo 'Usage: scripts/build-app.sh [debug|release] [arm64|x86_64]' >&2
    exit 2
fi
swift build -c "$configuration" --arch "$architecture" --product BetterWispr -Xswiftc -DDISABLE_APPLE_INTELLIGENCE
binary_dir="$(swift build -c "$configuration" --arch "$architecture" --show-bin-path)"
app="$binary_dir/Vaani.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
# SwiftPM checkout licenses/resources can be read-only after the first copy.
chmod -R u+w "$app"
cp "$binary_dir/BetterWispr" "$app/Contents/MacOS/BetterWispr"
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
rm -rf "$app/Contents/Resources/Licenses" "$app/Contents/Resources/BetterWispr_BetterWispr.bundle" "$app/Contents/MacOS/FluidAudio_FluidAudio.bundle" "$app/Contents/MacOS/BetterWispr_BetterWispr.bundle" "$app/Contents/Frameworks/Sparkle.framework"
ditto "$binary_dir/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
rm -rf "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$app/Contents/Frameworks/Sparkle.framework/XPCServices"
mkdir -p "$app/Contents/Resources/Licenses"
cp LICENSE "$app/Contents/Resources/Licenses/BetterWispr-Apache-2.0.txt"
cp .build/checkouts/argmax-oss-swift/LICENSE "$app/Contents/Resources/Licenses/Argmax-MIT.txt"
cp .build/checkouts/argmax-oss-swift/NOTICES "$app/Contents/Resources/Licenses/Argmax-NOTICES.txt"
cp .build/checkouts/FluidAudio/LICENSE "$app/Contents/Resources/Licenses/FluidAudio-Apache-2.0.txt"
cp .build/checkouts/swift-argument-parser/LICENSE.txt "$app/Contents/Resources/Licenses/Swift-Argument-Parser-Apache-2.0.txt"
cp .build/checkouts/Sparkle/LICENSE "$app/Contents/Resources/Licenses/Sparkle-MIT.txt"
# SwiftPM resources from speech/tokenizer dependencies must travel with the app.
for resource in "$binary_dir"/*.bundle; do
    [[ -d "$resource" ]] || continue
    [[ "$(basename "$resource")" == BetterWispr_BetterWispr.bundle ]] && continue
    cp -R "$resource" "$app/Contents/Resources/"
    [[ "$(basename "$resource")" == FluidAudio_* ]] && continue
    cp -R "$resource" "$app/Contents/MacOS/"
done
identity="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk '/\)/ {print $2; exit}' || true)}"
if [[ -z "$identity" ]]; then
    identity=-
    echo 'warning: ad-hoc signing changes on every build, so macOS revokes Accessibility (paste) each time. Set CODESIGN_IDENTITY to keep it.' >&2
fi
codesign --force --deep --sign "$identity" --entitlements Resources/BetterWispr.entitlements "$app"
echo "$app"
