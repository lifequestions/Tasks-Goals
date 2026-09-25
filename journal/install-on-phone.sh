#!/bin/bash
# Builds the journal app and installs it on the iPhone over Wi‑Fi (no cable, no TestFlight).
# Run on the Mac:  ./journal/install-on-phone.sh
# The phone must be unlocked, on the same Wi‑Fi, and paired with this Mac in Xcode once.
set -euo pipefail
cd "$(dirname "$0")"

BRANCH="claude/adoring-faraday-5opi29"
BUNDLE_ID="com.desouza.lifequestionsjournal"

echo "→ Getting the latest code"
git fetch origin "$BRANCH"
git merge --ff-only "origin/$BRANCH"

if [ -n "$(git status --porcelain -- Undercurrent Undercurrent.xcodeproj)" ]; then
  echo "Note: this Mac has local edits to the app that aren't on GitHub:"
  git status --short -- Undercurrent Undercurrent.xcodeproj
fi

echo "→ Building (1–3 minutes)"
LOG="$(mktemp -t undercurrent-build)"
if ! xcodebuild -project Undercurrent.xcodeproj -scheme Undercurrent -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates build >"$LOG" 2>&1; then
  echo "✗ The build failed. The errors:"
  grep -E "error:|error -|No Account|provisioning profile|Signing for" "$LOG" | sort -u | head -25
  echo "(Full log: $LOG)"
  exit 1
fi
APP="build/Build/Products/Debug-iphoneos/Undercurrent.app"

echo "→ Finding the iPhone"
DEVICES_JSON="$(mktemp)"
xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null
DEVICE="${DEVICE:-$(python3 - "$DEVICES_JSON" <<'EOF'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
phones = [d for d in devices
          if d.get("hardwareProperties", {}).get("platform") == "iOS"
          and d.get("connectionProperties", {}).get("pairingState") == "paired"]
print(phones[0]["identifier"] if phones else "")
EOF
)}"
rm -f "$DEVICES_JSON"
if [ -z "$DEVICE" ]; then
  echo "No paired iPhone found. Unlock it, check it's on the same Wi‑Fi, and try again." >&2
  exit 1
fi

echo "→ Installing"
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" || true
echo "✓ Installed on the iPhone"
