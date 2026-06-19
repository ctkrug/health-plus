#!/usr/bin/env bash
#
# crashlogs.sh — get a readable (symbolicated) crash trace for HealthSync.
#
# Usage:
#   ./scripts/crashlogs.sh /path/to/Foo.ips     # symbolicate a specific crash file
#   ./scripts/crashlogs.sh                       # pull crash logs from a USB-connected iPhone
#
# Where crash files come from:
#   • iPhone:  Settings → Privacy & Security → Analytics & Improvements → Analytics Data
#              → find "HealthAggregator-YYYY-MM-DD-...ips" → Share → AirDrop to your Mac.
#   • Xcode:   Window → Organizer → Crashes tab (auto-symbolicated; needs a few hours after a crash).
#   • Connected device: this script can pull them if `libimobiledevice` is installed.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/HealthAggregator"
ARCHIVE_DSYMS="$APP_DIR/build/HealthAggregator.xcarchive/dSYMs"

cyan()  { printf "\033[0;36m%s\033[0m\n" "$1"; }
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
red()   { printf "\033[0;31m%s\033[0m\n" "$1"; }

symbolicate() {
  local ips="$1"
  [ -f "$ips" ] || { red "✗ File not found: $ips"; exit 1; }
  cyan "▸ Symbolicating $ips"
  local TOOL
  TOOL=$(/usr/bin/xcrun --find symbolicatecrash 2>/dev/null || \
    find /Applications/Xcode.app -name symbolicatecrash 2>/dev/null | head -1)
  if [ -n "${TOOL:-}" ] && [ -d "$ARCHIVE_DSYMS" ]; then
    export DEVELOPER_DIR="$(/usr/bin/xcode-select -p)"
    DEVELOPER_DIR="$DEVELOPER_DIR" "$TOOL" "$ips" "$ARCHIVE_DSYMS" 2>/dev/null || {
      red "symbolicatecrash failed — showing raw file instead:"; cat "$ips"; }
  else
    red "No symbolicatecrash tool or dSYMs found (build/HealthAggregator.xcarchive/dSYMs)."
    echo "Modern .ips files are JSON and often already symbolicated. Showing the file:"
    cat "$ips"
  fi
}

if [ $# -ge 1 ]; then
  symbolicate "$1"
  exit 0
fi

# No arg: try to pull from a connected device.
if command -v idevicecrashreport >/dev/null 2>&1; then
  OUT="$APP_DIR/build/device-crashlogs"
  mkdir -p "$OUT"
  cyan "▸ Pulling crash reports from connected device → $OUT"
  idevicecrashreport -e "$OUT" >/dev/null 2>&1 || true
  LATEST=$(ls -t "$OUT"/HealthAggregator* 2>/dev/null | head -1 || true)
  if [ -n "${LATEST:-}" ]; then
    green "✓ Latest: $LATEST"
    symbolicate "$LATEST"
  else
    red "No HealthAggregator crash reports found on the device."
  fi
else
  red "libimobiledevice not installed (needed to pull from a USB device)."
  echo "Install it with:  brew install libimobiledevice"
  echo "Or grab the .ips from the phone (Settings → Privacy → Analytics Data) and run:"
  echo "  ./scripts/crashlogs.sh /path/to/HealthAggregator-....ips"
fi
