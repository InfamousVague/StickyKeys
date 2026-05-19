import AppKit
import SwiftUI

/// Full-screen "keyboard is locked" overlay on every display. The mouse stays
/// live (the key tap doesn't touch the pointer), so the big Unlock button
/// works. Sits just below the menu bar so the status-item icon is also still
/// clickable as a second way out.
///
/// The backdrop is a heavy *behind-window* blur of the live screen with no
/// color wash — strong enough to read the white overlay text, but the screen
/// underneath is just frosted, not darkened or tinted.
@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []

    func show(store: LockStore) {
        hide()
        let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        for screen in NSScreen.screens {
            let w = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            w.level = level
            w.isOpaque = false
            w.backgroundColor = .clear            // no tint — blur does the work
            w.ignoresMouseEvents = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.isMovable = false
            w.hasShadow = false

            // Intense, untinted frost of whatever is behind the window.
            let blur = NSVisualEffectView(
                frame: NSRect(origin: .zero, size: screen.frame.size)
            )
            blur.autoresizingMask = [.width, .height]
            blur.blendingMode = .behindWindow
            blur.material = .fullScreenUI         // the strongest neutral blur
            blur.state = .active

            let host = NSHostingView(rootView: LockOverlayView(store: store))
            host.frame = blur.bounds
            host.autoresizingMask = [.width, .height]
            blur.addSubview(host)

            w.contentView = blur
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
        }
    }

    func hide() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
    }
}

private struct LockOverlayView: View {
    @State var store: LockStore

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(.white)
            Text("Keyboard locked for cleaning")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            Text("Wipe away — every key, modifier and media key is ignored.\nNothing you press runs.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                store.unlock()
            } label: {
                Text("Unlock keyboard")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Text("…or click the StickyKeys menu-bar icon. "
                 + "Auto-unlocks in \(timeString(store.secondsRemaining)).")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .id(store.tick)   // re-render the countdown each tick
        }
        // Legibility on a clear frost (does not tint the backdrop).
        .shadow(color: .black.opacity(0.55), radius: 8, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
