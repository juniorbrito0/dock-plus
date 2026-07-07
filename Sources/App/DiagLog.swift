import Foundation

// Diagnostics written to ~/Library/Logs/DockPlus.log (survives restarts, readable without Console
// log-level quirks) plus NSLog. Used to trace the permission-request flow.
enum DiagLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/DockPlus.log")

    private static let queue = DispatchQueue(label: "ai.brito.cooldock.diaglog")

    static func log(_ message: String) {
        NSLog("DOCKPLUS %@", message)
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp)  \(message)\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                try? data.write(to: url)
            } else if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                // Throwing variants: the legacy seekToEndOfFile()/write() raise an uncatchable
                // ObjC exception on I/O failure, which would crash the app from a log write.
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } catch {}
            }
        }
    }
}
