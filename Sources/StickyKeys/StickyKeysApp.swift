import SwiftUI
import AppKit
import StickyKeysPane
import SuiteKit

// Standalone StickyKeys. Post-split this is just a host shim — the
// lock engine, overlay, store and UI live in `StickyKeysPane` so the
// MattsSoftware launcher can load the same code out of an installed
// StickyKeys.app. Behaviour unchanged (incl. click-to-unlock).
@main
struct StickyKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate,
    NSPopoverDelegate
{
    private let pane = StickyKeysPaneProvider()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SuiteGuard.exitIfDeferring("stickykeys")

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = pane.paneMenuBarImage()
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        pane.onMenuBarImageChange = { [weak self] img in
            self?.statusItem.button?.image = img
        }
        pane.onLockChange = { [weak self] locked in
            if locked, self?.popover.isShown == true {
                self?.popover.performClose(nil)
            }
        }

        let vc = NSViewController()
        vc.view = pane.paneMakeView()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = vc

        pane.paneStart()
    }

    @objc private func togglePopover(_ sender: Any?) {
        // While locked, a menu-bar click is a fast unlock.
        if pane.isLocked { pane.unlock(); return }
        if popover.isShown { popover.performClose(sender) }
        else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button,
                         preferredEdge: .minY)
            if let win = popover.contentViewController?.view.window {
                clampOnScreen(win, anchoredTo: button)
                win.makeKey()
            }
            NSApp.activate(ignoringOtherApps: true)
            if let m = clickMonitor { NSEvent.removeMonitor(m) }
            clickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in self?.popover.performClose(nil) }
        }
    }

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
            NSEvent.removeMonitor(m); clickMonitor = nil
        }
    }
}
