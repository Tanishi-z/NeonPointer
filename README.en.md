# Neon Pointer

English | [日本語](README.md)

A macOS menu bar app that draws a translucent neon shape around your mouse cursor, making it easier to spot on screen.

Landing page: https://tanishi-z.github.io/NeonPointer/

- Shapes: circle / ring / cross / square
- Adjustable color, size, opacity, glow intensity, and line width
- Toggle on/off and change all settings from the menu bar
- Settings are saved automatically (`UserDefaults`)
- The overlay is click-through, so it never gets in the way of the app underneath
- Cursor position is read only via `NSEvent.mouseLocation`, so **no Accessibility permission is required**

## Requirements

- macOS 14 or later
- Xcode 15 or later (used for command-line builds)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```sh
make build   # produces dist/NeonPointer.app
make run     # build and launch
make dmg     # produces dist/NeonPointer.dmg
make clean   # remove build artifacts
```

`NeonPointer.xcodeproj` is generated automatically from `project.yml`. Don't edit it directly — change `project.yml` instead.

## Install

1. Download `NeonPointer.dmg` from [Releases](https://github.com/Tanishi-z/NeonPointer/releases/latest) and open it (or `dist/NeonPointer.dmg` if you built it yourself)
2. Drag `NeonPointer.app` into `Applications`
3. The first time only, **right-click → Open** the app and confirm "Open"

Since the app is unsigned, double-clicking it will show a "developer cannot be verified" warning. If it still won't open, run:

```sh
xattr -cr /Applications/NeonPointer.app
```

## Signing for distribution

If you have an Apple Developer Program Developer ID, you can pass your signing identity via an environment variable.

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make dmg
```

To notarize the app, run `xcrun notarytool submit` and `xcrun stapler staple` against the generated dmg.

## Project layout

| File | Role |
| --- | --- |
| `Sources/NeonPointer/NeonPointerApp.swift` | Entry point. Defines the `MenuBarExtra` |
| `Sources/NeonPointer/AppDelegate.swift` | Starts and stops the overlay |
| `Sources/NeonPointer/SettingsStore.swift` | Settings model and persistence |
| `Sources/NeonPointer/PointerShape.swift` | Shape definitions and `CGPath` generation |
| `Sources/NeonPointer/OverlayPanel.swift` | Click-through, all-spaces overlay panel |
| `Sources/NeonPointer/NeonCursorView.swift` | Neon rendering via `CAShapeLayer` |
| `Sources/NeonPointer/CursorTracker.swift` | Cursor tracking via `CADisplayLink` |
| `Sources/NeonPointer/OverlayController.swift` | Wires together settings, tracking, and rendering |
| `Sources/NeonPointer/SettingsView.swift` | SwiftUI settings screen |

## License

[MIT License](LICENSE)
