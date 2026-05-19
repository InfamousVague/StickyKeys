import AppKit
import SwiftUI
import SuiteKit

/// StickyKeys as a SuiteKit pane. Owns the lock store AND the
/// full-screen overlay so the keyboard-lock works identically
/// whether hosted standalone or merged into the launcher. The
/// mouse-only ways out (overlay Unlock button + safety auto-unlock
/// timer) are always present, satisfying the safety invariant even
/// when there's no dedicated menu-bar icon.
@MainActor
public final class StickyKeysPaneProvider: NSObject, SuitePane {
    private let store = LockStore()
    private let overlay = OverlayController()

    /// Host/shim refreshes the segment/menu-bar glyph.
    public var onMenuBarImageChange: ((NSImage) -> Void)?
    /// Host/shim dismisses its popover when the keyboard locks.
    public var onLockChange: ((Bool) -> Void)?

    public override init() {
        super.init()
        store.onLockChange = { [weak self] locked in
            guard let self else { return }
            self.onMenuBarImageChange?(self.paneMenuBarImage())
            if locked { self.overlay.show(store: self.store) }
            else { self.overlay.hide() }
            self.onLockChange?(locked)
        }
    }

    public var suiteABIVersion: Int { SuiteKitABI.current }
    public var paneID: String { "stickykeys" }
    public var paneTitle: String { "STICKYKEYS" }
    public var paneTintHex: String { "#C58AF9" }

    /// Standalone convenience: a menu-bar click while locked is a
    /// fast unlock. The host can use these too.
    public var isLocked: Bool { store.isLocked }
    public func unlock() { store.unlock() }

    public func paneMenuBarImage() -> NSImage { icon(store.isLocked) }

    public func paneMakeView() -> NSView {
        NSHostingView(rootView: ContentView().environment(store))
    }

    public func paneStart() { store.refreshPermission() }

    public func paneStop() {
        // Safety: never leave the keyboard trapped if unmerged.
        if store.isLocked { store.unlock() }
    }

    private func icon(_ locked: Bool) -> NSImage {
        let img = NSImage(
            systemSymbolName: locked ? "lock.fill" : "keyboard",
            accessibilityDescription: "StickyKeys") ?? NSImage()
        img.isTemplate = true
        return img
    }
}

@_cdecl("suitePaneCreate")
public func suitePaneCreate() -> Unmanaged<AnyObject> {
    MainActor.assumeIsolated {
        Unmanaged.passRetained(StickyKeysPaneProvider())
    }
}
