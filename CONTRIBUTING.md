# Contributing to NotchNudge

Thanks for helping out. NotchNudge is meant to stay small, fast, and quiet, so the best changes keep it that way.

## Build and run

You need macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). No Xcode project is required.

```bash
make run          # builds build/NotchNudge.app and opens it
```

## Project layout

| Path | What it does |
| --- | --- |
| `Sources/NotchNudge/main.swift` | App startup, menu bar icon, global shortcut |
| `Sources/NotchNudge/NotchController.swift` | The floating notch window, mouse tracking, the reminder timer |
| `Sources/NotchNudge/Views.swift` | All the SwiftUI screens (drawer, rows, reminder card) |
| `Sources/NotchNudge/Store.swift` | Reminders, saving to disk, picking what is due |
| `scripts/screenshots/main.swift` | Draws the README images and app icon from the real views (`make screenshots`) |
| `Makefile` | All build steps: `make`, `make run`, `make dmg`, `make screenshots` |

## Pull requests

1. Open an issue first for anything bigger than a bug fix.
2. Keep the app free of network calls, analytics, and new dependencies.
3. If you change how something looks, run `make screenshots` and include the updated images.
4. Make sure `make` succeeds.

## Releasing (maintainers)

Push a tag like `v1.1.0`. GitHub Actions builds the app and attaches the `.dmg` and `.zip` to the release.
