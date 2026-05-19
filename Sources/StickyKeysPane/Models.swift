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
    /// One prompt + one Settings jump per launch. macOS TCC is keyed
    /// to the HOST process's identity, so a merged StickyKeys (whose
    /// host is the launcher, not StickyKeys.app) may never be
    /// auto-granted — without this guard every lock attempt would
    /// re-spawn the system prompt and re-open System Settings.
    @ObservationIgnored private var didRequest = false

    /// The app actually hosting this pane: "MattsSoftware" when
    /// merged into the launcher, "StickyKeys" when standalone. The
    /// Accessibility / Input Monitoring grant must go to THIS app —
    /// granting it to a different one (e.g. StickyKeys.app while the
    /// launcher hosts the pane) has no effect.
    var hostAppName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleName")
            as? String) ?? ProcessInfo.processInfo.processName
    }

    func refreshPermission() {
        permitted = keyboard.isPermitted
        if permitted { lastError = nil; didRequest = false }
    }

    func requestPermission() {
        refreshPermission()
        guard !permitted else { return }
        if !didRequest {
            didRequest = true
            _ = keyboard.promptForPermission()
            if let url = URL(string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        lastError = "Grant Accessibility (and Input Monitoring) to "
            + "“\(hostAppName)” in System Settings → Privacy & "
            + "Security, then try locking again."
    }

    func toggle() { isLocked ? unlock() : lock() }

    func lock() {
        guard !isLocked else { return }
        refreshPermission()
        guard permitted else {
            requestPermission()   // sets host-aware guidance (throttled)
            return
        }
        guard keyboard.start() else {
            permitted = false
            requestPermission()
            lastError = "macOS blocked the keyboard tap — “\(hostAppName)” "
                + "needs Accessibility & Input Monitoring. Grant it in "
                + "System Settings, then retry."
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
