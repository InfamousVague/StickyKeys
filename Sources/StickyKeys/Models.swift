import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class LockStore {
    private(set) var isLocked = false
    private(set) var permitted = false
    private(set) var lockedSince: Date?
    /// Safety net: auto-unlock after this many seconds so you can never get
    /// trapped (the manual mouse unlock is still the primary exit).
    var autoUnlockSeconds = 120
    var lastError: String?

    /// Bumped by a timer while locked so the overlay countdown re-renders.
    private(set) var tick = Date()

    @ObservationIgnored private let keyboard = KeyboardLock()
    @ObservationIgnored var onLockChange: ((Bool) -> Void)?
    @ObservationIgnored private var safetyTimer: Timer?
    @ObservationIgnored private var tickTimer: Timer?

    func refreshPermission() {
        permitted = keyboard.isPermitted
    }

    func requestPermission() {
        _ = keyboard.promptForPermission()
        if let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshPermission()
    }

    func toggle() { isLocked ? unlock() : lock() }

    func lock() {
        guard !isLocked else { return }
        refreshPermission()
        guard permitted else {
            lastError = "Accessibility permission needed."
            requestPermission()
            return
        }
        guard keyboard.start() else {
            permitted = false
            lastError = "macOS rejected the keyboard tap — grant Accessibility & Input Monitoring."
            requestPermission()
            return
        }
        lastError = nil
        isLocked = true
        lockedSince = Date()

        let limit = max(10, autoUnlockSeconds)
        safetyTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(limit),
                                           repeats: false) { [weak self] _ in
            Task { @MainActor in self?.unlock() }
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick = Date() }
        }
        onLockChange?(true)
    }

    func unlock() {
        guard isLocked else { return }
        keyboard.stop()
        isLocked = false
        lockedSince = nil
        safetyTimer?.invalidate(); safetyTimer = nil
        tickTimer?.invalidate(); tickTimer = nil
        onLockChange?(false)
    }

    /// Whole seconds until the safety auto-unlock fires.
    var secondsRemaining: Int {
        guard let since = lockedSince else { return 0 }
        let left = TimeInterval(max(10, autoUnlockSeconds)) - Date().timeIntervalSince(since)
        return max(0, Int(left.rounded(.up)))
    }
}
