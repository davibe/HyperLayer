import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct SecureInputOwner: Equatable {
    let processIdentifier: pid_t
    let name: String
}

final class PermissionManager: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var secureInputOwner: SecureInputOwner?

    private var timer: Timer?

    init() {
        refresh()
    }

    deinit {
        timer?.invalidate()
    }

    func startPolling(every interval: TimeInterval = 10.0, onRecheck: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }
            self.refresh()
            onRecheck()
        }
    }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
        secureInputOwner = currentSecureInputOwner()
    }

    func requestAccessibility() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func openAccessibilitySettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func openSettingsPane(_ string: String) {
        guard let url = URL(string: string) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func currentSecureInputOwner() -> SecureInputOwner? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let processNumber = session["kCGSSessionSecureInputPID"] as? NSNumber else {
            return nil
        }

        let processIdentifier = processNumber.int32Value
        guard processIdentifier > 0,
              processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        let name = NSRunningApplication(processIdentifier: processIdentifier)?.localizedName
            ?? "PID \(processIdentifier)"
        return SecureInputOwner(processIdentifier: processIdentifier, name: name)
    }

}
