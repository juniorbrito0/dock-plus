import Foundation
import AppKit

struct EmailItem: Identifiable {
    let id: Int
    let sender: String
    let subject: String
}

// Latest inbox messages from Mail.app via AppleScript. Mail's `inbox` is the unified inbox.
// We never `tell application "Mail"` unless it is already running, because a literal tell
// would force-launch Mail.
@MainActor
@Observable
final class EmailService {
    static let shared = EmailService()

    private(set) var messages: [EmailItem] = []
    private(set) var isMailRunning = false

    private var task: Task<Void, Never>?

    private init() {}

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func activateMail() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mail.app"))
    }

    private func refresh() async {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        guard running.contains("com.apple.mail") else {
            isMailRunning = false
            messages = []
            return
        }
        isMailRunning = true

        let output = await AppleScriptRunner.run(Self.inboxScript)
        messages = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                let fields = line.components(separatedBy: "\t")
                guard fields.count == 3, let id = Int(fields[0].trimmingCharacters(in: .whitespaces)) else { return nil }
                return EmailItem(id: id, sender: Self.displayName(from: fields[1]), subject: fields[2])
            }
    }

    func archive(_ item: EmailItem) async {
        guard isMailRunning else { return }
        messages.removeAll { $0.id == item.id }
        _ = await AppleScriptRunner.run(Self.archiveScript(id: item.id))
        await refresh()
    }

    func delete(_ item: EmailItem) async {
        guard isMailRunning else { return }
        messages.removeAll { $0.id == item.id }
        _ = await AppleScriptRunner.run(Self.deleteScript(id: item.id))
        await refresh()
    }

    func snooze(_ item: EmailItem) async {
        guard isMailRunning else { return }
        messages.removeAll { $0.id == item.id }
        _ = await AppleScriptRunner.run(Self.snoozeScript(id: item.id))
        await refresh()
    }

    private static func displayName(from sender: String) -> String {
        if let range = sender.range(of: " <") {
            let name = String(sender[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return sender.trimmingCharacters(in: CharacterSet(charactersIn: "<>")).trimmingCharacters(in: .whitespaces)
    }

    private static let inboxScript = """
    tell application "Mail"
        set out to ""
        set theMessages to messages of inbox
        set n to 0
        repeat with m in theMessages
            if n is 3 then exit repeat
            set out to out & (id of m) & tab & (sender of m) & tab & (subject of m) & linefeed
            set n to n + 1
        end repeat
        return out
    end tell
    """

    // Best-effort move to an "Archive" mailbox. Archive availability varies by account type
    // (IMAP/Exchange usually expose one; some POP setups don't), so failure is swallowed.
    private static func archiveScript(id: Int) -> String {
        """
        tell application "Mail"
            try
                set m to (first message of inbox whose id is \(id))
                set acct to account of mailbox of m
                try
                    set mailbox of m to (first mailbox of acct whose name is "Archive")
                on error
                    set mailbox of m to (first mailbox whose name is "Archive")
                end try
            end try
        end tell
        """
    }

    private static func deleteScript(id: Int) -> String {
        """
        tell application "Mail"
            try
                delete (first message of inbox whose id is \(id))
            end try
        end tell
        """
    }

    // Mail's "Remind Me" snooze (hide now, resurface pinned to top) is absent from Mail's
    // AppleScript dictionary, so it must be driven by UI scripting through System Events. This
    // needs Accessibility permission for the process running osascript AND Automation permission
    // for Mail, and the menu titles below are English-locale specific. The whole thing is wrapped
    // in `try` blocks so a missing menu (other locale, OS change) degrades to a no-op rather than
    // surfacing an error. The id is an Int, so there is no injection surface.
    private static func snoozeScript(id: Int) -> String {
        """
        tell application "Mail"
            activate
            try
                set selected messages of message viewer 1 to {first message of inbox whose id is \(id)}
            end try
        end tell
        delay 0.3
        tell application "System Events" to tell process "Mail"
            try
                set remindMenu to menu 1 of menu item "Remind Me" of menu "Message" of menu bar 1
                try
                    click menu item "Remind Me Tomorrow" of remindMenu
                on error
                    repeat with mi in (menu items of remindMenu)
                        set t to name of mi
                        if t is not missing value and t does not end with "…" and t does not end with "..." then
                            click mi
                            exit repeat
                        end if
                    end repeat
                end try
            end try
        end tell
        """
    }
}
