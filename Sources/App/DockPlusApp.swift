import SwiftUI

@main
struct DockPlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("Dock+", systemImage: "square.grid.2x2") {
            Button("Settings & Permissions…") { activateSettings() }
                .keyboardShortcut(",")
            Button("Toggle Minimize") { DockChrome.shared.minimized.toggle() }
            Divider()
            Button("Quit Dock+") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }

        Window("Dock+", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private func activateSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dock: DockWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        LoginItemService.shared.synchronize()

        AppsService.shared.load()
        EmojiService.shared.load()
        FoldersService.shared.load()
        BookmarksService.shared.load()
        PermissionsService.shared.refresh()
        PermissionsService.shared.logLaunchDiagnostics()

        SystemStatsService.shared.start()
        BatteryService.shared.start()
        CalendarService.shared.start()
        RemindersService.shared.start()
        WeatherService.shared.start()
        MusicService.shared.start()
        EmailService.shared.start()
        DiaService.shared.start()

        dock = DockWindowController()
        dock?.show()
        WindowGuardService.shared.start()
    }
}
