# StickyKeys (Linux)

Linux-native sibling of the macOS Swift build at the repo root. Same
product name and version as the Mac build, **separate native
binary**.

## Status

**Scaffold only.** macOS is the current shipping artifact. Linux
work lands here incrementally. Read the **Honest ceilings** section
before promising a Wayland release — keyboard-grab on Wayland is
genuinely harder than on macOS or X11.

## Stack

| Layer            | Choice                                                |
| ---------------- | ----------------------------------------------------- |
| Language         | Rust (2021)                                           |
| X11 keyboard grab| `x11rb` → `XGrabKeyboard` + `GrabModeAsync`           |
| Wayland keyboard | `wayland-client` + `zwp_input_method_v2` / virtual-keyboard protocols (compositor-dependent) |
| Tray             | [`ksni`](https://docs.rs/ksni)                        |
| Fullscreen overlay | GTK4 + [`gtk4-layer-shell`](https://github.com/wmww/gtk4-layer-shell) (Wayland), X11 `override-redirect` window otherwise |
| Safety timer     | `tokio` single-thread runtime                         |
| Packaging        | `.deb` · `.rpm` · Flatpak                             |

## What "lock the keyboard" means on Linux

| Surface          | Mac (current)                          | Linux                                            |
| ---------------- | -------------------------------------- | ------------------------------------------------ |
| Consume all keys | `CGEventTap`, return `nil`             | **X11:** `XGrabKeyboard` (works); **Wayland:** input-method-v2 grab via compositor cooperation (Sway, KWin yes; mutter/GNOME limited) |
| Fullscreen blur  | `NSWindow` per-screen                  | `gtk4-layer-shell` overlay layer per-output      |
| Mouse stays live | n/a — pointer events bypass tap        | Don't grab the pointer; rely on overlay buttons  |
| Auto-unlock timer| `Timer.scheduledTimer`                 | `tokio::time::sleep`                             |

## Honest ceilings (read me before promising features)

- **Wayland**: there is no portable equivalent of `CGEventTap`. The closest is the *input-method* and *virtual-keyboard* protocols, both of which require **compositor cooperation**. Sway and KWin expose them; GNOME's mutter does not at all. On vanilla GNOME-Wayland, full keyboard consumption is **not possible** — we'll degrade to "show overlay, beg the user not to type."
- **X11**: `XGrabKeyboard` cleanly swallows every key while the grab is active. This is the strongest path; ship X11 first.
- **Always preserve the mouse exit** (overlay button + safety auto-unlock). Same safety invariant as macOS.
- **Wayland tray**: GNOME needs AppIndicator extension; KDE / Sway / others work natively.

## Roadmap

1. X11 MVP: grab keyboard, show overlay, mouse-only unlock + safety timer.
2. `ksni` tray + lock toggle.
3. Wayland (Sway / KWin / wlroots) via virtual-keyboard / input-method-v2.
4. GNOME-Wayland degraded mode with an honest UI ceiling note.
5. Packaging in CI.
