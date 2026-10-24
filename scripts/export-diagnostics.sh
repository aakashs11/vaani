#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-$project_root/local/diagnostics-$(date +%Y%m%d-%H%M%S)}"
mkdir -m 700 -p "$output"
logs="$HOME/Library/Logs/org.betterwispr.app"
if [[ -d "$logs" ]]; then ditto "$logs" "$output/events"; fi
/usr/bin/sw_vers > "$output/macos.txt"
git -C "$project_root" rev-parse HEAD > "$output/upstream-commit.txt"
git -C "$project_root" diff --stat > "$output/local-changes.txt"
for crash in "$HOME/Library/Logs/DiagnosticReports"/BetterWispr*.ips; do
    [[ -f "$crash" ]] && cp "$crash" "$output/"
done
printf 'Local diagnostics saved to %s\nTranscript history and audio are not included.\n' "$output"
