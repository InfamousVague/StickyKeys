# stickykeys (native)

Native macOS menu-bar keyboard lock for cleaning. Click the menu-bar item to
**lock the keyboard** — every key, modifier, and media key is swallowed so
wiping the keys with a cloth runs no shortcuts or commands. A full-screen
overlay shows it's locked; you **unlock with the mouse** (the overlay button
or the menu-bar item). A safety timer auto-unlocks so you can never get
trapped. Swift + SwiftUI, `NSStatusItem` + `.accessory`, no third-party deps.

## Commit Convention
Angular commits required with scope. See @.claude/rules/commit-rules.md.

## Code Style
See @.claude/rules/code-style.md

## How it works

- `Sources/StickyKeys/KeyboardLock.swift` — an **active** `CGEventTap`
  (`.cgSessionEventTap`, `.defaultTap`) over keyDown/keyUp/flagsChanged +
  NSSystemDefined (media keys). The callback returns `nil` to drop the event
  while locked; it re-enables itself if the system disables the tap. The tap
  is created only while locked and fully torn down on unlock.
- `Sources/StickyKeys/OverlayController.swift` — borderless top-most window on
  every screen; mouse stays live so the big **Unlock** button works.
- `Sources/StickyKeys/Models.swift` — `LockStore` (`@Observable`,
  `@MainActor`): lock state, permission state, safety auto-unlock timer.
- `Sources/StickyKeys/StickyKeysApp.swift` — `@main` app: `NSStatusItem` +
  `NSPopover` + `.accessory`.
- `Sources/StickyKeys/ContentView.swift` — popover: lock toggle, permission
  status, safety-timeout setting, Quit.

## Permissions

Consuming key events needs **Accessibility** (and Input Monitoring) granted in
System Settings → Privacy & Security. The app detects `AXIsProcessTrusted()`
and guides the user; the Developer-ID-signed `/Applications` build keeps the
grant stable across launches.

## Running

```
swift build
swift run                 # menu-bar item appears; no Dock icon
bash scripts/make-app.sh  # StickyKeys.app, Developer ID signed + notarized
open StickyKeys.app
```
