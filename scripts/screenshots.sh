#!/bin/bash
# Regenerates README screenshots and the app icon from the real SwiftUI views.
# Usage: ./scripts/screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14.0" "${OVERLAY[@]}" -o .build/snapshot \
  Sources/NotchNudge/Store.swift Sources/NotchNudge/NotchController.swift Sources/NotchNudge/Views.swift \
  scripts/screenshots/main.swift
.build/snapshot docs/images

# Build the .icns app icon from the 1024px render.
ICONSET=.build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s docs/images/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) docs/images/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
sips -z 256 256 docs/images/icon-1024.png --out docs/images/icon.png >/dev/null
rm docs/images/icon-1024.png
echo "Updated docs/images and Resources/AppIcon.icns"
