import SwiftUI
import AppKit

// A live snapshot of one Dia browser tab. Read over AppleScript (Dia ships a scripting definition
// exposing windows → tabs with title/URL and a `focus` command).
struct DiaTab: Identifiable, Sendable, Equatable {
    let id: String            // "windowIndex.tabIndex"
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String

    var host: String { URLDisplay.host(of: url) }
}

@MainActor
@Observable
final class DiaService {
    static let shared = DiaService()

    private(set) var tabs: [DiaTab] = []
    private(set) var isRunning = false
    private(set) var lastError: String?

    static let bundleID = "company.thebrowser.dia"

    private var task: Task<Void, Never>?
    private var refreshing = false

    private init() {}

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID)
    }

    var appIcon: NSImage {
        let icon = appURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage()
        icon.size = NSSize(width: 40, height: 40)
        return icon
    }

    func start() {
        guard task == nil else { return }
        Task { await refresh() }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }

        isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == Self.bundleID }
        guard isRunning else { tabs = []; lastError = nil; return }

        let result = await AppleScriptRunner.runCapturingErrors(Self.readScript)
        if let error = result.error, result.output.isEmpty {
            lastError = error
            return
        }
        lastError = nil
        tabs = Self.parse(result.output)
    }

    func focus(_ tab: DiaTab) {
        // Match on the live URL at execution time — positional indexes go stale the moment Dia's
        // tabs are opened, closed, or reordered after the last poll.
        let escaped = tab.url.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Dia"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) is "\(escaped)" then
                        focus t
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        Task { _ = await AppleScriptRunner.run(script) }
        activate()
    }

    private func activate() {
        guard let appURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }

    // Unit/record separators (ASCII 31/30) can't appear in titles or URLs, so parsing is unambiguous.
    private static let readScript = """
    tell application "Dia"
        set fs to (character id 31)
        set rs to (character id 30)
        set out to ""
        set wi to 0
        repeat with w in windows
            set wi to wi + 1
            set ti to 0
            repeat with t in tabs of w
                set ti to ti + 1
                set out to out & wi & fs & ti & fs & (title of t) & fs & (URL of t) & rs
            end repeat
        end repeat
        return out
    end tell
    """

    private static func parse(_ raw: String) -> [DiaTab] {
        raw.split(separator: "\u{1E}").compactMap { record in
            let fields = record.split(separator: "\u{1F}", omittingEmptySubsequences: false)
            guard fields.count == 4,
                  let wi = Int(fields[0]), let ti = Int(fields[1]) else { return nil }
            return DiaTab(id: "\(wi).\(ti)", windowIndex: wi, tabIndex: ti,
                          title: String(fields[2]), url: String(fields[3]))
        }
    }
}
