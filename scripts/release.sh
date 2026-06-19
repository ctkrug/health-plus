#!/usr/bin/env bash
#
# release.sh — one-command pipeline: validate → bump build → commit/push → archive → upload to TestFlight.
#
# Usage:
#   ./scripts/release.sh "commit message describing the change"
#
# What it does, in order:
#   1. Preflight (type-check both targets, regenerate project). Aborts on any error.
#   2. Auto-increment the build number (CURRENT_PROJECT_VERSION) in project.yml.
#   3. git add -A, commit with your message, push to origin/main.
#   4. xcodebuild archive (Release, generic iOS device).
#   5. xcodebuild -exportArchive with destination=upload → pushes to App Store Connect / TestFlight.
#
# Authentication for step 5 (App Store Connect API key) — set these once in your shell
# profile (~/.zshrc) or a local scripts/.env file (git-ignored):
#   export ASC_KEY_ID="XXXXXXXXXX"            # the key's Key ID
#   export ASC_ISSUER_ID="xxxxxxxx-xxxx-..."  # your issuer UUID
#   export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
# Generate the key at: App Store Connect → Users and Access → Integrations → App Store Connect API.
#
# If the API key vars are NOT set, the script still does steps 1–4 and produces a .ipa,
# then tells you to upload it manually via Xcode Organizer or Transporter.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/HealthAggregator"
BUILD_DIR="$APP_DIR/build"
SCHEME="HealthAggregator"
PROJECT="HealthAggregator.xcodeproj"
ARCHIVE_PATH="$BUILD_DIR/HealthAggregator.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTS="$REPO_ROOT/scripts/ExportOptions.plist"

cyan()  { printf "\033[0;36m%s\033[0m\n" "$1"; }
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
red()   { printf "\033[0;31m%s\033[0m\n" "$1"; }
bold()  { printf "\033[1m%s\033[0m\n" "$1"; }

# Load local env file if present (for ASC_* keys).
[ -f "$REPO_ROOT/scripts/.env" ] && source "$REPO_ROOT/scripts/.env"

# --- 0. Args ---------------------------------------------------------------
if [ $# -lt 1 ] || [ -z "$1" ]; then
  red "✗ Missing commit message."
  echo "Usage: ./scripts/release.sh \"what changed\""
  exit 1
fi
COMMIT_MSG="$1"

bold "═══ HealthSync release pipeline ═══"

# --- 1. Preflight ----------------------------------------------------------
"$REPO_ROOT/scripts/preflight.sh"

# --- 2. Bump build number --------------------------------------------------
cd "$APP_DIR"
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml | sed 's/[^0-9]//g')
NEXT_BUILD=$(( CURRENT_BUILD + 1 ))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"$NEXT_BUILD\"/g" project.yml
MARKETING_VERSION=$(grep -m1 'MARKETING_VERSION:' project.yml | sed 's/.*"\(.*\)".*/\1/')
cyan "▸ Build number: $CURRENT_BUILD → $NEXT_BUILD (version $MARKETING_VERSION)"
xcodegen generate >/dev/null   # apply new build number to the .xcodeproj

# --- 3. Commit & push ------------------------------------------------------
cd "$REPO_ROOT"
cyan "▸ Committing & pushing to GitHub…"
git add -A
git commit -m "$COMMIT_MSG

Build $NEXT_BUILD (v$MARKETING_VERSION)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { red "Nothing to commit (or commit failed)"; }

# Ensure we're not on a detached head; push current branch to origin.
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$BRANCH"
green "  ✓ pushed to origin/$BRANCH"

# --- 4. Archive ------------------------------------------------------------
cd "$APP_DIR"
rm -rf "$BUILD_DIR"
cyan "▸ Archiving (this takes a few minutes)…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  | xcbeautify 2>/dev/null || xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates
green "  ✓ archived"

# --- 5. Export + upload ----------------------------------------------------
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  cyan "▸ Uploading to TestFlight via App Store Connect API…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    -authenticationKeyPath "$ASC_KEY_PATH"
  green "✓ Uploaded build $NEXT_BUILD to TestFlight."
  echo "   It will appear in App Store Connect → TestFlight in ~5–10 min (you'll get an email)."
  echo "   First build of a version also needs: Manage Compliance → No encryption."
else
  # No API key — export an .ipa for manual upload.
  cyan "▸ No ASC API key set — exporting .ipa for manual upload…"
  # Build a throwaway options plist with destination=export (never touch the committed file).
  mkdir -p "$BUILD_DIR"
  TMP_OPTS="$BUILD_DIR/ExportOptions.local.plist"
  cp "$EXPORT_OPTS" "$TMP_OPTS"
  /usr/libexec/PlistBuddy -c "Set :destination export" "$TMP_OPTS"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$TMP_OPTS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates
  green "✓ Built build $NEXT_BUILD."
  bold "  Manual upload needed (no API key configured):"
  echo "   • .ipa is at: $EXPORT_PATH"
  echo "   • Open Xcode → Window → Organizer → Archives → Distribute App, OR"
  echo "   • Open the Transporter app and drag in the .ipa."
  echo "   To automate uploads, set ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH (see header of this script)."
fi

bold "═══ Done ═══"
