#!/bin/bash
# Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
# Vaani modification, 2026: explicit owner credentials, Apple Silicon release, no upstream appcast.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == --setup-notary ]]; then
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your own Apple Developer team ID}"
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your own Keychain profile name}"
    read -r -p 'Apple ID email: ' apple_id
    [[ -n "$apple_id" ]] || exit 1
    exec xcrun notarytool store-credentials "$NOTARY_PROFILE" --apple-id "$apple_id" --team-id "$APPLE_TEAM_ID"
fi
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your own Developer ID Application identity}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your own Apple Developer team ID}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your own Keychain profile name}"
[[ "$SIGNING_IDENTITY" != - && "$SIGNING_IDENTITY" == *"($APPLE_TEAM_ID)"* ]] || { echo 'Signing identity must belong to APPLE_TEAM_ID.' >&2; exit 1; }
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
mkdir -p .build
staging="$(mktemp -d .build/vaani-release.XXXXXX)"
trap 'rm -rf "$staging"' EXIT
app="$(CODESIGN_IDENTITY=- bash scripts/build-app.sh release arm64 | tail -1)"
python3 Tests/branding_check.py "$app"
[[ "$(lipo -archs "$app/Contents/MacOS/Vaani")" == arm64 ]] || { echo 'Expected arm64 executable.' >&2; exit 1; }
codesign --deep --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" --entitlements Resources/Vaani.entitlements "$app"
codesign --verify --deep --strict "$app"
dmg="$staging/Vaani-arm64.dmg"
bash scripts/create-dmg.sh "$app" "$dmg"
codesign --timestamp --sign "$SIGNING_IDENTITY" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"
release_dir="${RELEASE_DIR:-release}"
mkdir -p "$release_dir"
mv "$dmg" "$release_dir/Vaani-arm64.dmg"
shasum -a 256 "$release_dir/Vaani-arm64.dmg" > "$release_dir/Vaani-arm64.dmg.sha256"
echo "Release verified: $release_dir/Vaani-arm64.dmg"
echo 'Publication is a separate action. No upstream update feed is generated.'
