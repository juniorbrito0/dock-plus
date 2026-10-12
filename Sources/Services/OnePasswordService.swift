import Foundation
import AppKit

// Search 1Password and copy a username, password or one-time code to the clipboard via the `op` CLI. The CLI brokers
// auth through the desktop app (Touch ID / app integration), so no secrets are ever passed
// as arguments — `op` resolves the unlocked session itself.
@MainActor
@Observable
final class OnePasswordService {
    static let shared = OnePasswordService()

    struct OPItem: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        let url: URL?
    }

    enum Field {
        case username, password, oneTimeCode

        var label: String {
            switch self {
            case .username: "username"
            case .password: "password"
            case .oneTimeCode: "code"
            }
        }

        var args: [String] {
            switch self {
            case .username: ["--fields", "label=username"]
            case .password: ["--fields", "label=password", "--reveal"]
            case .oneTimeCode: ["--otp"]
            }
        }
    }

    enum OPStatus {
        case unknown
        case ready
        case needsAuth
        case unavailable
    }

    private(set) var items: [OPItem] = []
    private(set) var status: OPStatus = .unknown
    private(set) var lastCopied: String?
    private(set) var lastError = ""

    private var clearToastTask: Task<Void, Never>?

    private init() {}

    func loadItems() async {
        let result = await Self.run(["item", "list", "--categories", "Login", "--format=json", "--cache"])
        guard result.ok else {
            lastError = (result.err + " " + result.out).trimmingCharacters(in: .whitespacesAndNewlines)
            status = Self.failureStatus(from: result.err + " " + result.out)
            return
        }
        lastError = ""
        guard let data = result.out.data(using: .utf8),
              let listed = try? JSONDecoder().decode([ListedItem].self, from: data) else {
            return
        }
        items = listed.map { listed in
            let href = listed.urls?.first(where: { $0.primary == true })?.href ?? listed.urls?.first?.href
            let subtitle = listed.additionalInformation ?? href ?? ""
            return OPItem(id: listed.id, title: listed.title, subtitle: subtitle, url: Self.websiteURL(href))
        }
        status = .ready
    }

    func filtered(_ query: String) -> [OPItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(items.prefix(20)) }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.subtitle.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func copy(_ field: Field, of item: OPItem) async {
        let result = await Self.run(["item", "get", item.id] + field.args)
        let value = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.ok, !value.isEmpty else {
            // An item without that field (most often no one-time code) isn't an auth failure.
            let output = (result.err + " " + result.out).lowercased()
            if result.ok || output.contains("does not") || output.contains("no ") {
                showToast("No \(field.label) saved for \(item.title)")
            } else {
                status = Self.failureStatus(from: output)
            }
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        scheduleClipboardClear(value)
        showToast("Copied \(field.label) ✓ \(item.title)")
    }

    func openWebsite(_ item: OPItem) {
        guard let url = item.url else {
            showToast("No website saved for \(item.title)")
            return
        }
        NSWorkspace.shared.open(url)
    }

    // 1Password stores bare hosts ("github.com") as often as full URLs; give those a scheme.
    private static func websiteURL(_ href: String?) -> URL? {
        guard let href = href?.trimmingCharacters(in: .whitespaces), !href.isEmpty else { return nil }
        let full = href.contains("://") ? href : "https://\(href)"
        // Only web links: a vault item (possibly from a shared vault) could carry a file:// or
        // app-specific scheme that NSWorkspace would happily open.
        guard let url = URL(string: full), url.host != nil,
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }

    private func showToast(_ message: String) {
        lastCopied = message
        clearToastTask?.cancel()
        clearToastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.lastCopied = nil
        }
    }

    // Don't leave a revealed credential on the clipboard indefinitely; clear it if untouched.
    private func scheduleClipboardClear(_ password: String) {
        Task {
            try? await Task.sleep(for: .seconds(90))
            let pasteboard = NSPasteboard.general
            if pasteboard.string(forType: .string) == password {
                pasteboard.clearContents()
            }
        }
    }

    private static func failureStatus(from output: String) -> OPStatus {
        let lower = output.lowercased()
        if lower.contains("not signed in") || lower.contains("authorization")
            || lower.contains("not currently signed in") || lower.contains("session") {
            return .needsAuth
        }
        if lower.contains("no such file") || lower.contains("not found")
            || lower.contains("executable") {
            return .unavailable
        }
        return .needsAuth
    }

    private nonisolated static let opPath: String? = {
        for path in ["/opt/homebrew/bin/op", "/usr/local/bin/op"] where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }()

    // stdout and stderr are kept separate: `op` writes the password (and JSON) to stdout, and
    // notices/errors to stderr — merging them would corrupt a copied secret.
    private nonisolated static func run(_ args: [String]) async -> OPResult {
        guard let opPath else { return OPResult(out: "", err: "not found", ok: false) }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: opPath)
                process.arguments = args
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: watchdog)
                do {
                    try process.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    watchdog.cancel()
                    let out = String(data: outData, encoding: .utf8) ?? ""
                    let err = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(returning: OPResult(out: out, err: err, ok: process.terminationStatus == 0))
                } catch {
                    watchdog.cancel()
                    continuation.resume(returning: OPResult(out: "", err: "not found", ok: false))
                }
            }
        }
    }
}

private struct OPResult {
    let out: String
    let err: String
    let ok: Bool
}

private struct ListedItemURL: Decodable {
    let href: String
    let primary: Bool?
}

private struct ListedItem: Decodable {
    let id: String
    let title: String
    let additionalInformation: String?
    let urls: [ListedItemURL]?

    enum CodingKeys: String, CodingKey {
        case id, title, urls
        case additionalInformation = "additional_information"
    }
}
