# NotchNudge build recipes. Needs macOS 14+ and the Xcode Command Line Tools.
#   make              build build/NotchNudge.app (Apple Silicon + Intel)
#   make run          build and open it
#   make dmg          build dist/NotchNudge.dmg and dist/NotchNudge.zip
#   make screenshots  re-draw the README images and the app icon
#   make clean        remove build output

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
VERSION ?= 1.1.0

APP     := build/NotchNudge.app
SOURCES := $(wildcard Sources/NotchNudge/*.swift)
TARGET  := -apple-macos14.0

# Work around a Command Line Tools bug ("redefinition of module 'SwiftBridging'")
# by hiding one of the two duplicate module maps. Not needed when full Xcode is selected.
DUP := /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
NEEDS_OVERLAY := $(shell [ "$$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ] && [ -f $(DUP) ] && [ -f $(dir $(DUP))bridging.modulemap ] && echo yes)
ifeq ($(NEEDS_OVERLAY),yes)
OVERLAY := -vfsoverlay .build/overlay.yaml
OVERLAY_FILE := .build/overlay.yaml
endif
SWIFTC := swiftc -O -swift-version 5 $(OVERLAY)

.PHONY: app run dmg screenshots clean
.DEFAULT_GOAL := app

.build/overlay.yaml:
	mkdir -p .build
	: > .build/empty.modulemap
	printf '{ "version": 0, "roots": [ { "name": "%s", "type": "file", "external-contents": "%s" } ] }\n' \
	  "$(DUP)" "$(CURDIR)/.build/empty.modulemap" > $@

app: $(OVERLAY_FILE)
	mkdir -p .build
	$(SWIFTC) -target arm64$(TARGET)  -o .build/NotchNudge-arm64  $(SOURCES)
	$(SWIFTC) -target x86_64$(TARGET) -o .build/NotchNudge-x86_64 $(SOURCES)
	lipo -create -output .build/NotchNudge .build/NotchNudge-arm64 .build/NotchNudge-x86_64
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/NotchNudge $(APP)/Contents/MacOS/NotchNudge
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	sed 's/__VERSION__/$(VERSION)/g' Resources/Info.plist > $(APP)/Contents/Info.plist
	codesign --force --deep --sign - $(APP)
	@echo "Built $(APP) (version $(VERSION))"

run: app
	open $(APP)

dmg: app
	rm -rf dist .build/dmg
	mkdir -p dist .build/dmg
	cp -R $(APP) .build/dmg/
	ln -s /Applications .build/dmg/Applications
	hdiutil create -volname NotchNudge -srcfolder .build/dmg -ov -format UDZO dist/NotchNudge.dmg >/dev/null
	ditto -c -k --keepParent $(APP) dist/NotchNudge.zip
	cd dist && shasum -a 256 NotchNudge.dmg NotchNudge.zip > SHA256SUMS.txt
	@ls -lh dist

screenshots: $(OVERLAY_FILE)
	mkdir -p .build
	$(SWIFTC) -target $$(uname -m)$(TARGET) -o .build/snapshot \
	  Sources/NotchNudge/Store.swift Sources/NotchNudge/NotchController.swift Sources/NotchNudge/Views.swift \
	  scripts/screenshots/main.swift
	.build/snapshot docs/images
	rm -rf .build/AppIcon.iconset && mkdir -p .build/AppIcon.iconset
	for s in 16 32 128 256 512; do \
	  sips -z $$s $$s docs/images/icon-1024.png --out .build/AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
	  sips -z $$((s*2)) $$((s*2)) docs/images/icon-1024.png --out .build/AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns .build/AppIcon.iconset -o Resources/AppIcon.icns
	sips -z 256 256 docs/images/icon-1024.png --out docs/images/icon.png >/dev/null
	rm docs/images/icon-1024.png

clean:
	rm -rf .build build dist
