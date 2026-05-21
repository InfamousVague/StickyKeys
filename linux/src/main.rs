//! Linux build of StickyKeys. Scaffold only — see ../README.md
//! for the X11 (works) vs Wayland (compositor-dependent)
//! implementation plan and the honest ceilings.
//!
//! Real version: X11 first (XGrabKeyboard), then Wayland via the
//! virtual-keyboard / input-method-v2 protocols where compositors
//! cooperate (Sway, KWin), with a graceful "no full grab" mode on
//! mutter / GNOME-Wayland.

fn main() {
    eprintln!(
        "stickykeys (linux): scaffold only — see linux/README.md \
         for the implementation plan and the Wayland ceilings."
    );
    std::process::exit(0);
}
