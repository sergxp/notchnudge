# Shared by build scripts. Works around a Command Line Tools bug where two files both
# define the SwiftBridging module ("redefinition of module 'SwiftBridging'") by hiding one copy.
OVERLAY=()
DUP=/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ] && [ -f "$DUP" ] && [ -f "$(dirname "$DUP")/bridging.modulemap" ]; then
  mkdir -p .build
  : > .build/empty.modulemap
  printf '{ "version": 0, "roots": [ { "name": "%s", "type": "file", "external-contents": "%s" } ] }\n' \
    "$DUP" "$(pwd)/.build/empty.modulemap" > .build/overlay.yaml
  OVERLAY=(-vfsoverlay .build/overlay.yaml)
fi
