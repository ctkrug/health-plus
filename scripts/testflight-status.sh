#!/usr/bin/env bash
#
# testflight-status.sh — query App Store Connect for recent builds and beta (TestFlight)
# feedback, using the same API key as release.sh. No external deps (JWT signed with openssl).
#
# Usage:  ./scripts/testflight-status.sh
#
# Shows: the latest builds and their processing state (so you can confirm a release landed),
# plus any TestFlight tester feedback / crash submissions the API exposes.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$REPO_ROOT/scripts/.env" ] && source "$REPO_ROOT/scripts/.env"

BUNDLE_ID="com.ctkrug.healthplus"
API="https://api.appstoreconnect.apple.com"

: "${ASC_KEY_ID:?set up scripts/.env first (./scripts/setup-asc.sh)}"
: "${ASC_ISSUER_ID:?missing ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?missing ASC_KEY_PATH}"

cyan()  { printf "\033[0;36m%s\033[0m\n" "$1"; }
bold()  { printf "\033[1m%s\033[0m\n" "$1"; }

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

# --- Build an ES256 JWT for App Store Connect ---
make_jwt() {
  local now exp header payload h p der rlen r soff slen s sig
  now=$(date +%s); exp=$((now + 1200))
  header="{\"alg\":\"ES256\",\"kid\":\"$ASC_KEY_ID\",\"typ\":\"JWT\"}"
  payload="{\"iss\":\"$ASC_ISSUER_ID\",\"iat\":$now,\"exp\":$exp,\"aud\":\"appstoreconnect-v1\"}"
  h=$(printf '%s' "$header"  | b64url)
  p=$(printf '%s' "$payload" | b64url)
  # ES256 signature: openssl emits DER; JWT needs raw R||S (32 bytes each).
  der=$(printf '%s' "$h.$p" | openssl dgst -sha256 -sign "$ASC_KEY_PATH" -binary | xxd -p -c 4096 | tr -d '\n')
  rlen=$((16#${der:6:2}))
  r=${der:8:$((rlen * 2))}
  soff=$((8 + rlen * 2))
  slen=$((16#${der:$((soff + 2)):2}))
  s=${der:$((soff + 4)):$((slen * 2))}
  pad() { local x=$1; x=${x#00}; while [ ${#x} -lt 64 ]; do x="0$x"; done; printf '%s' "$x"; }
  sig=$(printf '%s%s' "$(pad "$r")" "$(pad "$s")" | xxd -r -p | b64url)
  printf '%s.%s.%s' "$h" "$p" "$sig"
}

JWT=$(make_jwt)
auth=( -H "Authorization: Bearer $JWT" )

get() { curl -fsS "${auth[@]}" "$API$1"; }

# --- Resolve app ---
APP_ID=$(get "/v1/apps?filter%5BbundleId%5D=$BUNDLE_ID&limit=1" | jq -r '.data[0].id // empty')
if [ -z "$APP_ID" ]; then
  echo "Could not find app $BUNDLE_ID (check the key has access)."; exit 1
fi
bold "App: $BUNDLE_ID  (id $APP_ID)"

# --- Recent builds ---
echo
cyan "▸ Recent builds (newest first):"
get "/v1/builds?filter%5Bapp%5D=$APP_ID&sort=-uploadedDate&limit=8&fields%5Bbuilds%5D=version,uploadedDate,processingState,expired" \
  | jq -r '.data[] | "  build \(.attributes.version)  \(.attributes.processingState)  \(.attributes.uploadedDate)\(if .attributes.expired then "  (expired)" else "" end)"'

# --- TestFlight tester feedback (best-effort: API surface varies by account/entitlement) ---
echo
cyan "▸ TestFlight crash feedback (most recent):"
if get "/v1/apps/$APP_ID/betaFeedbackCrashSubmissions?limit=5&sort=-createdDate" 2>/dev/null \
   | jq -e '.data | length > 0' >/dev/null 2>&1; then
  get "/v1/apps/$APP_ID/betaFeedbackCrashSubmissions?limit=5&sort=-createdDate" \
    | jq -r '.data[] | "  \(.attributes.createdDate)  \(.attributes.deviceModel // "?")  \(.attributes.osVersion // "")"'
else
  echo "  (none, or not exposed to this key — also check App Store Connect → TestFlight → Feedback)"
fi

echo
cyan "▸ TestFlight screenshot feedback (most recent):"
if get "/v1/apps/$APP_ID/betaFeedbackScreenshotSubmissions?limit=5&sort=-createdDate" 2>/dev/null \
   | jq -e '.data | length > 0' >/dev/null 2>&1; then
  get "/v1/apps/$APP_ID/betaFeedbackScreenshotSubmissions?limit=5&sort=-createdDate" \
    | jq -r '.data[] | "  \(.attributes.createdDate)  \(.attributes.deviceModel // "?")  “\(.attributes.comment // "")”"'
else
  echo "  (none, or not exposed to this key — also check App Store Connect → TestFlight → Feedback)"
fi
