#!/bin/bash
# NotchNudge installer
#   curl -fsSL https://raw.githubusercontent.com/sergxp/notchnudge/main/install.sh | bash
# Downloads the latest release, puts it in /Applications, and opens it.
set -euo pipefail

REPO="sergxp/notchnudge"
URL="https://github.com/$REPO/releases/latest/download/NotchNudge.zip"

major=$(sw_vers -productVersion | cut -d. -f1)
if [ "$major" -lt 14 ]; then
  echo "NotchNudge needs macOS 14 (Sonoma) or newer. You have $(sw_vers -productVersion)." >&2
  exit 1
fi

DEST="/Applications"
if [ ! -w "$DEST" ]; then DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading NotchNudge..."
curl -fL --progress-bar "$URL" -o "$TMP/NotchNudge.zip"
ditto -x -k "$TMP/NotchNudge.zip" "$TMP"

echo "==> Installing to $DEST"
pkill -x NotchNudge 2>/dev/null || true
rm -rf "$DEST/NotchNudge.app"
mv "$TMP/NotchNudge.app" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/NotchNudge.app" 2>/dev/null || true

open "$DEST/NotchNudge.app"
echo ""
echo "NotchNudge is running. Hover over the notch, or press Control + Option + N."
