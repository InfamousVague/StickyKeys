import SwiftUI
import AppKit

@main
struct StickyKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Accessory app: the real UI is the status item / popover / overlay
        // the delegate manages. This scene stays empty.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let store = LockStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let overlay = OverlayController()
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.icon(locked: false)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environment(store)
        )

        store.refreshPermission()
        store.onLockChange = { [weak self] locked in
            guard let self else { return }
            self.statusItem.button?.image = Self.icon(locked: locked)
            if locked {
                if self.popover.isShown { self.popover.performClose(nil) }
                self.overlay.show(store: self.store)
            } else {
                self.overlay.hide()
            }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        // While locked, a click on the menu-bar icon is a fast unlock.
        if store.isLocked {
            store.unlock()
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if let win = popover.contentViewController?.view.window {
                clampOnScreen(win, anchoredTo: button)
                win.makeKey()
            }
            NSApp.activate(ignoringOtherApps: true)
            if let m = clickMonitor { NSEvent.removeMonitor(m) }
            clickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in
                self?.popover.performClose(nil)
            }
        }
    }

    /// Keep the popover fully on the screen that holds the status
    /// item. NSPopover centers on the icon and clips when the icon
    /// is near a screen edge (notably far right / next to the
    /// notch); shift the window back inside the visible frame.
    private func clampOnScreen(_ win: NSWindow, anchoredTo anchor: NSView) {
        guard let screen = anchor.window?.screen ?? NSScreen.main
        else { return }
        let vis = screen.visibleFrame
        let pad: CGFloat = 8
        var f = win.frame
        if f.maxX > vis.maxX - pad { f.origin.x = vis.maxX - pad - f.width }
        if f.minX < vis.minX + pad { f.origin.x = vis.minX + pad }
        if f.minY < vis.minY + pad { f.origin.y = vis.minY + pad }
        if f != win.frame { win.setFrame(f, display: true) }
    }

    func popoverDidClose(_ notification: Notification) {
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
    }

    private static func icon(locked: Bool) -> NSImage? {
        let name = locked ? "lock.fill" : "keyboard"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "StickyKeys")
        img?.isTemplate = true
        return img
    }
}
