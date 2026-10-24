#!/bin/bash
# Vaani modification, 2026: compatible hdiutil packaging with atomic output replacement.
set -euo pipefail
if [[ $# != 2 || ! -d "$1/Contents" || "$2" != *.dmg ]]; then
    echo 'Usage: scripts/create-dmg.sh Vaani.app output.dmg' >&2
    exit 2
fi
app="$(cd "$1" && pwd)"
mkdir -p "$(dirname "$2")"
output_dir="$(cd "$(dirname "$2")" && pwd)"
output="$output_dir/$(basename "$2")"
work="$(mktemp -d "$output_dir/.vaani-dmg.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/staging"
ditto "$app" "$work/staging/Vaani.app"
ln -s /Applications "$work/staging/Applications"
hdiutil create -volname Vaani -srcfolder "$work/staging" -format UDZO "$work/Vaani.dmg" >/dev/null
hdiutil verify "$work/Vaani.dmg" >/dev/null
mv "$work/Vaani.dmg" "$output"
echo "$output"
