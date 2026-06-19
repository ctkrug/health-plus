#!/usr/bin/env bash
#
# test.sh — run the automated regression suite (XCTest) on a simulator.
#
# This is the "did we break anything?" gate. Run it before a release, or periodically.
# It regenerates the Xcode project, boots an iPhone simulator, and runs every unit test.
#
# Usage:
#   ./scripts/test.sh                 # auto-pick the newest available iPhone simulator
#   ./scripts/test.sh "iPhone 17"     # pin a specific simulator by name
#
# Exit code is non-zero if any test fails (so CI / release.sh can gate on it).
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/HealthAggregator"

cyan()  { printf "\033[0;36m%s\033[0m\n" "$1"; }
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
red()   { printf "\033[0;31m%s\033[0m\n" "$1"; }
bold()  { printf "\033[1m%s\033[0m\n" "$1"; }

cd "$APP_DIR"

bold "═══ HealthSync test suite ═══"

# 1. Regenerate the Xcode project so new test files are picked up.
cyan "▸ Regenerating Xcode project (xcodegen)…"
if ! command -v xcodegen >/dev/null 2>&1; then
  red "✗ xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi
xcodegen generate >/dev/null
green "  ✓ project regenerated"

# 2. Pick a simulator.
SIM_NAME="${1:-}"
if [ -z "$SIM_NAME" ]; then
  # Newest available iPhone simulator by name (e.g. "iPhone 17 Pro").
  SIM_NAME="$(xcrun simctl list devices available | grep -oE 'iPhone [0-9]+[^(]*' | sed 's/ *$//' | sort -V | tail -1)"
fi
if [ -z "$SIM_NAME" ]; then
  red "✗ No available iPhone simulator found. Open Xcode → Settings → Components to add one."
  exit 1
fi
cyan "▸ Using simulator: $SIM_NAME"

# 3. Run the tests. Always capture the full log to a file; pretty-print only if xcbeautify
#    is installed (piping into a missing binary would SIGPIPE-truncate the log).
cyan "▸ Running xcodebuild test…"
mkdir -p "$APP_DIR/build"
LOG="$APP_DIR/build/test-output.log"
rm -rf "$APP_DIR/build/TestResults.xcresult"
set +e
xcodebuild test \
  -project HealthAggregator.xcodeproj \
  -scheme HealthAggregator \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -resultBundlePath "$APP_DIR/build/TestResults.xcresult" \
  -only-testing:HealthAggregatorTests \
  CODE_SIGNING_ALLOWED=NO \
  > "$LOG" 2>&1
TEST_STATUS=$?
set -e

if command -v xcbeautify >/dev/null 2>&1; then
  xcbeautify < "$LOG" || true
else
  # Plain summary: the per-suite execution lines.
  grep -aoE "Executed [0-9]+ tests?, with [0-9]+ failures?[^.]*" "$LOG" | tail -5 || true
fi

echo ""
# Prefer the executed-tests summary if present; fall back to xcodebuild's own verdict line.
SUMMARY="$(grep -aoE "Executed [0-9]+ tests?, with [0-9]+ failures?" "$LOG" | tail -1)"
if [ "$TEST_STATUS" -eq 0 ]; then
  green "═══ ✓ All tests passed — ${SUMMARY:-build succeeded} ═══"
else
  red "═══ ✗ Tests FAILED (see $LOG) ═══"
  # Distinguish a compile failure from a test assertion failure, and surface the details.
  if grep -aq "Testing failed:" "$LOG"; then
    sed 's/\x1b\[[0-9;]*m//g' "$LOG" | sed -n '/Testing failed:/,/^$/p' | head -30
  fi
  grep -aE "error:|XCTAssert.* failed|failed - " "$LOG" | grep -av "0 failures" | head -40 || true
fi

exit "$TEST_STATUS"
