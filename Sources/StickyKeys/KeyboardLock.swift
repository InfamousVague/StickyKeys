import Foundation
import CoreGraphics
import ApplicationServices

/// C event-tap callback. While the tap is installed every keyboard / modifier
/// / media event is dropped (return nil). If the system disables the tap
/// (slow callback or user-input timeout) we re-enable it and pass that
/// control event through.
private func skTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon {
            Unmanaged<KeyboardLock>.fromOpaque(refcon).takeUnretainedValue().reenable()
        }
        return Unmanaged.passUnretained(event)
    }
    return nil   // locked → swallow the keystroke
}

/// Owns the active `CGEventTap`. The tap exists only while locked and is fully
/// torn down on unlock, so an unlocked machine has zero residual hooks.
final class KeyboardLock {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Accessibility is required to *consume* events with an active tap.
    var isPermitted: Bool { AXIsProcessTrusted() }

    @discardableResult
    func promptForPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Installs the tap. Returns false if macOS rejected it (no permission).
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (UInt64(1) << CGEventType.keyDown.rawValue) |
            (UInt64(1) << CGEventType.keyUp.rawValue) |
            (UInt64(1) << CGEventType.flagsChanged.rawValue) |
            (UInt64(1) << 14)   // NSSystemDefined: brightness / volume / media

        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: skTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
        source = src
        return true
    }

    func stop() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        if let src = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        if let t = tap { CFMachPortInvalidate(t) }
        source = nil
        tap = nil
    }

    func reenable() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
    }
}
