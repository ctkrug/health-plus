#!/usr/bin/env bash
#
# preflight.sh — fast local validation before any commit/release.
# Runs a Swift type-check on BOTH targets and regenerates the Xcode project.
# Exits non-zero on the first failure so callers (release.sh) can fail fast.
#
# Usage:  ./scripts/preflight.sh
#
set -euo pipefail

# Resolve repo root (this script lives in <repo>/scripts) and the Xcode project dir.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/HealthAggregator"

cyan()  { printf "\033[0;36m%s\033[0m\n" "$1"; }
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
red()   { printf "\033[0;31m%s\033[0m\n" "$1"; }

cd "$APP_DIR"

cyan "▸ Regenerating Xcode project (xcodegen)…"
if ! command -v xcodegen >/dev/null 2>&1; then
  red "✗ xcodegen not installed. Run: brew install xcodegen"
  exit 1
fi
xcodegen generate >/dev/null
green "  ✓ project regenerated"

# The app target now has a real SwiftPM dependency (MuscleMap), so a raw multi-file `swiftc
# -typecheck` can no longer see it (that mode has no package resolution — it always reports
# "no such module 'MuscleMap'", which is a false positive, not a real error). `xcodebuild build`
# resolves packages correctly and is what CI/test.sh actually trusts, so use it here too. Simulator
# + CODE_SIGNING_ALLOWED=NO keeps it fast and signing-free, matching test.sh's approach.
cyan "▸ Building app target (xcodebuild — resolves SwiftPM deps, unlike raw swiftc)…"
BUILD_LOG=$(mktemp)
if ! xcodebuild build \
  -project HealthAggregator.xcodeproj \
  -scheme HealthAggregator \
  -destination "generic/platform=iOS Simulator" \
  -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  > "$BUILD_LOG" 2>&1; then
  red "✗ App target has compile errors:"
  grep -aE "error:" "$BUILD_LOG" | sort -u || tail -40 "$BUILD_LOG"
  rm -f "$BUILD_LOG"
  exit 1
fi
rm -f "$BUILD_LOG"
green "  ✓ app target OK"

cyan "▸ Type-checking widget target…"
WIDGET_ERRORS=$(xcrun --sdk iphoneos swiftc -target arm64-apple-ios17.0 -parse-as-library -typecheck \
  -framework WidgetKit -framework SwiftUI -framework ActivityKit \
  HealthAggregatorWidgets/HealthAggregatorWidgets.swift 2>&1 | grep "error:" || true)
if [ -n "$WIDGET_ERRORS" ]; then
  red "✗ Widget target has compile errors:"
  echo "$WIDGET_ERRORS"
  exit 1
fi
green "  ✓ widget target OK"

green "✓ Preflight passed."
