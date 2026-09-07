# Neon Pointer

English | [日本語](README.md)

A macOS menu bar app that draws a translucent neon shape around your mouse cursor, making it easier to spot on screen.

Landing page: https://tanishi-z.github.io/NeonPointer/

- Shapes: circle / ring / cross / square
- Adjustable color, size, opacity, glow intensity, and line width
- **Hold a modifier key while moving the cursor to draw on screen** (the line fades away on its own after a while)
- Toggle on/off and change all settings from the menu bar
- Launches automatically at login
- Works across multiple displays
- Settings are saved automatically (`UserDefaults`)
- The overlay is click-through, so it never gets in the way of the app underneath
- Cursor position and modifier-key state are read purely by polling `NSEvent.mouseLocation` / `NSEvent.modifierFlags`, so **neither Accessibility nor Input Monitoring permission is required**

## Drawing on screen

Hold a modifier key (⌥ Option by default) while moving the cursor to leave a neon trail behind it. Release the key and the trail stays for a while, then fades out.

If you start drawing again before a fading trail disappears completely, it snaps back to full brightness. Once a trail has fully faded, it's gone for good.

| Setting | Default | Range |
| --- | --- | --- |
| Modifier key | ⌥ | ⌥ / ⌃ / ⇧ / ⌘ / fn |
| Hold before fading | 2.0 s | 0.2–30 s |
| Fade duration | 1.5 s | 0.1–10 s |
| Line width | 6 pt | 1–40 pt |
| Line glow | 14 | 0–60 |
| Color | Same as cursor | Can be set independently |

## Requirements

- macOS 14 or later

## Build

If you'd rather not use the prebuilt dmg from [Releases](https://github.com/Tanishi-z/NeonPointer/releases/latest), you can build it from source instead. This requires:

- Xcode 15 or later (used for command-line builds)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

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
| `Sources/NeonPointer/StrokeTrail.swift` | Manages trail stroke points, paths, and fade state |
| `Sources/NeonPointer/TrailModifier.swift` | Defines the modifier key that triggers trail drawing |
| `Sources/NeonPointer/LoginItemManager.swift` | Launch at login (`SMAppService`) |
| `Sources/NeonPointer/ColorPanelController.swift` | Controls the color picker panel (`NSColorPanel`) |

## License

[MIT License](LICENSE)
