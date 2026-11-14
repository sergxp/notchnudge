#!/bin/bash
# Builds the app, then makes the release downloads in dist/:
#   NotchNudge.dmg             drag-to-Applications installer
#   NotchNudge.zip             used by install.sh
# Usage: ./scripts/package.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-1.0.0}"
./scripts/build.sh "$VERSION"

rm -rf dist .build/dmg && mkdir -p dist .build/dmg
cp -R build/NotchNudge.app .build/dmg/
ln -s /Applications .build/dmg/Applications
hdiutil create -volname "NotchNudge" -srcfolder .build/dmg -ov -format UDZO "dist/NotchNudge.dmg" >/dev/null
ditto -c -k --keepParent build/NotchNudge.app dist/NotchNudge.zip
(cd dist && shasum -a 256 * > SHA256SUMS.txt)
ls -lh dist
