import AppKit

// One open Google Chrome tab, read over AppleScript. Chrome's tab `id` is stable for the tab's
// lifetime, so focusing by id still works after other tabs open, close or move.
struct ChromeTab: Identifiable, Sendable, Equatable {
    let id: Int
    let title: String
    let url: String

    var host: String {
        guard let host = URL(string: url)?.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

@MainActor
@Observable
final class ChromeTabsService {
    static let shared = ChromeTabsService()
    static let bundleID = "com.google.Chrome"

    private(set) var tabs: [ChromeTab] = []
    private(set) var isRunning = false
    private(set) var loading = false

    private init() {}

    // Read on demand (when the menu opens) rather than polling, so Chrome is only scripted when asked.
    func refresh() async {
        isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == Self.bundleID }
        guard isRunning else { tabs = []; return }
        loading = true
        defer { loading = false }
        let output = await AppleScriptRunner.run(Self.readScript, timeout: 10)
        tabs = Self.parse(output)
    }

    func focus(_ tab: ChromeTab) {
        // Chrome reports tab ids as text, so compare as text: a number never equals "123".
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                set i to 0
                repeat with t in tabs of w
                    set i to i + 1
                    if ((id of t) as text) is "\(tab.id)" then
                        set active tab index of w to i
                        set index of w to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        Task.detached { _ = await AppleScriptRunner.run(script, timeout: 10) }
    }

    // Unit/record separators (ASCII 31/30) can't appear in titles or URLs, so parsing is unambiguous.
    private static let readScript = """
    tell application "Google Chrome"
        set fs to (character id 31)
        set rs to (character id 30)
        set out to ""
        repeat with w in windows
            repeat with t in tabs of w
                set out to out & (id of t) & fs & (title of t) & fs & (URL of t) & rs
            end repeat
        end repeat
        return out
    end tell
    """

    private static func parse(_ raw: String) -> [ChromeTab] {
        raw.trimmingCharacters(in: .newlines).split(separator: "\u{1E}").compactMap { record in
            let fields = record.split(separator: "\u{1F}", omittingEmptySubsequences: false)
            guard fields.count == 3, let id = Int(fields[0]) else { return nil }
            return ChromeTab(id: id, title: String(fields[1]), url: String(fields[2]))
        }
    }
}
