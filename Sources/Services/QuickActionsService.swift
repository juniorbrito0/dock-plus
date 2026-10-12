import Foundation

struct QuickAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let run: @MainActor () -> Void
}

@MainActor
@Observable
final class QuickActionsService {
    static let shared = QuickActionsService()

    private(set) var enabledIDs: [String]

    private let defaultsKey = "quickActions"
    private static let defaultEnabled = ["screenshotFile", "sleepDisplay"]

    let catalog: [QuickAction] = [
        QuickAction(id: "screenshotFile", title: "Screenshot", symbol: "camera.viewfinder") {
            QuickActionsService.shell("/usr/sbin/screencapture", ["-i", QuickActionsService.desktopScreenshotPath()])
        },
        QuickAction(id: "screenshotClipboard", title: "Screenshot to Clipboard", symbol: "camera.on.rectangle") {
            QuickActionsService.shell("/usr/sbin/screencapture", ["-i", "-c"])
        },
        QuickAction(id: "sleepDisplay", title: "Sleep Display", symbol: "moon.fill") {
            QuickActionsService.shell("/usr/bin/pmset", ["displaysleepnow"])
        },
        QuickAction(id: "lockScreen", title: "Lock Screen", symbol: "lock.fill") {
            QuickActionsService.shell("/usr/bin/osascript", ["-e", QuickActionsService.lockScript])
        },
        QuickAction(id: "screenSaver", title: "Screen Saver", symbol: "sparkles.tv") {
            QuickActionsService.shell("/usr/bin/open", ["-a", "ScreenSaverEngine"])
        },
        QuickAction(id: "emptyTrash", title: "Empty Trash", symbol: "trash.fill") {
            QuickActionsService.shell("/usr/bin/osascript", ["-e", QuickActionsService.emptyTrashScript])
        },
        QuickAction(id: "toggleDarkMode", title: "Toggle Dark Mode", symbol: "circle.lefthalf.filled") {
            QuickActionsService.shell("/usr/bin/osascript", ["-e", QuickActionsService.darkModeScript])
        },
        QuickAction(id: "muteToggle", title: "Mute / Unmute", symbol: "speaker.slash.fill") {
            QuickActionsService.shell("/usr/bin/osascript", ["-e", QuickActionsService.muteScript])
        },
        QuickAction(id: "openDownloads", title: "Open Downloads", symbol: "arrow.down.circle.fill") {
            QuickActionsService.shell("/usr/bin/open", [QuickActionsService.downloadsPath()])
        }
    ]

    private static let lockScript =
        #"tell application "System Events" to keystroke "q" using {command down, control down}"#
    private static let emptyTrashScript = #"tell application "Finder" to empty trash"#
    private static let darkModeScript =
        "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
    private static let muteScript = "set volume output muted (not (output muted of (get volume settings)))"

    nonisolated private static func downloadsPath() -> String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    }

    private init() {
        enabledIDs = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? Self.defaultEnabled
    }

    func load() {
        if let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) {
            enabledIDs = stored
        }
    }

    var enabledActions: [QuickAction] {
        enabledIDs.compactMap { id in catalog.first { $0.id == id } }
    }

    func toggle(id: String) {
        if enabledIDs.contains(id) {
            enabledIDs.removeAll { $0 == id }
        } else {
            enabledIDs.append(id)
        }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        enabledIDs.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func run(_ action: QuickAction) {
        action.run()
    }

    private func persist() {
        UserDefaults.standard.set(enabledIDs, forKey: defaultsKey)
    }

    nonisolated private static func shell(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try? process.run()
    }

    nonisolated private static func desktopScreenshotPath() -> String {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "Screenshot \(formatter.string(from: Date())).png"
        return desktop.appendingPathComponent(name).path
    }
}
