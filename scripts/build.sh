#!/bin/bash
# Builds NotchNudge.app (runs on Apple Silicon and Intel Macs).
# Usage: ./scripts/build.sh [version]     e.g. ./scripts/build.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-1.0.0}"
source scripts/toolchain.sh

mkdir -p .build
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos14.0" ${OVERLAY[@]+"${OVERLAY[@]}"} \
    -o ".build/NotchNudge-$ARCH" Sources/NotchNudge/*.swift
done
lipo -create -output .build/NotchNudge .build/NotchNudge-arm64 .build/NotchNudge-x86_64

APP=build/NotchNudge.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/NotchNudge "$APP/Contents/MacOS/NotchNudge"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>NotchNudge</string>
  <key>CFBundleDisplayName</key><string>NotchNudge</string>
  <key>CFBundleIdentifier</key><string>io.github.sergxp.notchnudge</string>
  <key>CFBundleExecutable</key><string>NotchNudge</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "Built $(pwd)/$APP (version $VERSION)"
