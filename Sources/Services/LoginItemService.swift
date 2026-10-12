import Foundation
import ServiceManagement

// Registers Dock+ as a macOS login item so it relaunches automatically after every restart.
// Auto-enables once on first launch; after that the user's toggle in Settings is respected.
@MainActor
@Observable
final class LoginItemService {
    static let shared = LoginItemService()

    private let configuredKey = "loginItemConfigured"

    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

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
