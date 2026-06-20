#!/usr/bin/env bash
#
# test.sh — run the automated regression suite (XCTest) on a simulator.
#
# This is the "did we break anything?" gate. Run it before a release, or periodically.
#
# Speed notes: iOS tests must run on a simulator (the app uses HealthKit/UIKit/WidgetKit, so there's
# no macOS test destination). The cold simulator boot dominates wall-clock time, so this script
# REUSES an already-booted simulator when one exists and otherwise boots one and LEAVES IT BOOTED
# for the next run. Combined with incremental DerivedData builds, reruns are much faster.
#
# Usage:
#   ./scripts/test.sh                 # reuse a booted iPhone sim, else boot the newest available
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
START=$(date +%s)

bold "═══ HealthSync test suite ═══"

# 1. Regenerate the Xcode project so new test files are picked up.
if ! command -v xcodegen >/dev/null 2>&1; then
  red "✗ xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi
cyan "▸ Regenerating Xcode project (xcodegen)…"
xcodegen generate >/dev/null
green "  ✓ project regenerated"

# 2. Resolve a simulator UDID — reuse a booted one (fast), else pick/boot the newest iPhone.
#    NOTE: grep returns non-zero when it matches nothing, which would abort the script under
#    `set -e`/`pipefail`; every grep-based capture below ends in `|| true` so "no match" is benign.
resolve_udid_by_name() {
  xcrun simctl list devices available \
    | grep -E "^[[:space:]]+$1 " \
    | grep -oE '[0-9A-Fa-f-]{36}' | head -1 || true
}

SIM_NAME="${1:-}"
SIM_UDID=""

if [ -n "$SIM_NAME" ]; then
  SIM_UDID="$(resolve_udid_by_name "$SIM_NAME")"
else
  # Prefer a simulator that's already booted — zero boot cost.
  SIM_UDID="$(xcrun simctl list devices booted | grep -iE 'iPhone' | grep -oE '[0-9A-Fa-f-]{36}' | head -1 || true)"
  if [ -z "$SIM_UDID" ]; then
    # Newest available iPhone (sorted by name).
    LINE="$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone ' | sort -V | tail -1 || true)"
    SIM_UDID="$(echo "$LINE" | grep -oE '[0-9A-Fa-f-]{36}' | head -1 || true)"
  fi
fi

if [ -z "$SIM_UDID" ]; then
  red "✗ No available iPhone simulator found. Open Xcode → Settings → Components to add one."
  exit 1
fi
SIM_LABEL="$(xcrun simctl list devices | grep "$SIM_UDID" | head -1 | sed -E 's/^[[:space:]]+//; s/ \(.*//' || true)"

# 3. Boot it (and leave it booted for next time). bootstatus blocks until fully booted.
if xcrun simctl list devices booted | grep -q "$SIM_UDID"; then
  cyan "▸ Reusing booted simulator: $SIM_LABEL"
else
  cyan "▸ Booting simulator: $SIM_LABEL (left running for faster reruns)…"
  xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
fi

# 4. Run the tests against that specific simulator (id=… avoids a fresh cold boot).
cyan "▸ Running xcodebuild test…"
mkdir -p "$APP_DIR/build"
LOG="$APP_DIR/build/test-output.log"
rm -rf "$APP_DIR/build/TestResults.xcresult"
set +e
xcodebuild test \
  -project HealthAggregator.xcodeproj \
  -scheme HealthAggregator \
  -destination "platform=iOS Simulator,id=$SIM_UDID" \
  -resultBundlePath "$APP_DIR/build/TestResults.xcresult" \
  -only-testing:HealthAggregatorTests \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  > "$LOG" 2>&1
TEST_STATUS=$?
set -e

if command -v xcbeautify >/dev/null 2>&1; then
  xcbeautify < "$LOG" || true
else
  grep -aoE "Executed [0-9]+ tests?, with [0-9]+ failures?[^.]*" "$LOG" | tail -5 || true
fi

ELAPSED=$(( $(date +%s) - START ))
echo ""
SUMMARY="$(grep -aoE "Executed [0-9]+ tests?, with [0-9]+ failures?" "$LOG" | tail -1 || true)"
if [ "$TEST_STATUS" -eq 0 ]; then
  green "═══ ✓ All tests passed — ${SUMMARY:-build succeeded} (${ELAPSED}s) ═══"
else
  red "═══ ✗ Tests FAILED in ${ELAPSED}s (see $LOG) ═══"
  if grep -aq "Testing failed:" "$LOG"; then
    sed 's/\x1b\[[0-9;]*m//g' "$LOG" | sed -n '/Testing failed:/,/^$/p' | head -30
  fi
  grep -aE "error:|XCTAssert.* failed|failed - " "$LOG" | grep -av "0 failures" | head -40 || true
fi

exit "$TEST_STATUS"
