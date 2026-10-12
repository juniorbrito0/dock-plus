import Foundation
import ServiceManagement

// Registers Dock+ as a macOS login item so it relaunches automatically after every restart.
// Auto-enables once on first launch; after that the user's toggle in Settings is respected.
@MainActor
@Observable
final class LoginItemService {
    static let shared = LoginItemService()

    private let configuredKey = "loginItemConfigured"

    // Stored (not computed) so the Settings toggle re-renders: @Observable can't see changes
    // inside SMAppService, so a computed read left the checkbox snapping back after a click.
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled

    private init() {}

    // Called at launch: enable on first run, and otherwise re-register so the login item always
    // points at the current bundle path (self-heals if the app moved, e.g. build folder → /Applications).
    func synchronize() {
        if !UserDefaults.standard.bool(forKey: configuredKey) {
            UserDefaults.standard.set(true, forKey: configuredKey)
            setEnabled(true)
        } else if SMAppService.mainApp.status == .enabled {
            setEnabled(true)
        } else {
            // The user turned it off: clear any classic login item that would still relaunch us.
            removeLegacyLoginItems()
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                // register() is idempotent and refreshes the stored path even when already enabled.
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
                removeLegacyLoginItems()
            }
        } catch {
            DiagLog.log("LoginItem toggle failed: \(error.localizedDescription)")
        }
        refresh()
    }

    // Picks up changes made in System Settings ▸ General ▸ Login Items while Dock+ is running.
    func refresh() {
        let status = SMAppService.mainApp.status
        // .requiresApproval means it's registered but waiting on the user in System Settings;
        // show it as on so the click registers, and the system notification explains the rest.
        isEnabled = status == .enabled || status == .requiresApproval
    }

    // A classic login item (added via System Settings or an older build) launches the app too, but
    // SMAppService neither reports nor removes it, so "off" in Settings wouldn't stick without this.
    private func removeLegacyLoginItems() {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Dock+"
        let script = """
        tell application "System Events"
            delete (every login item whose name is "\(name)")
        end tell
        """
        Task.detached { _ = await AppleScriptRunner.run(script) }
    }
}
