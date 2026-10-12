import Foundation

// Runs an AppleScript via /usr/bin/osascript off the main thread, with a watchdog timeout.
// Without the timeout, a wedged target app (or a blocking TCC/consent prompt) leaves osascript
// running forever, the awaiting continuation never resumes, and the caller's poll loop stalls —
// each subsequent action then spawns another permanently-blocked thread. The watchdog terminates
// a stuck process, which closes the pipe, unblocks the read, and lets the continuation resume once.
enum AppleScriptRunner {
    struct Result: Sendable {
        let output: String
        let error: String?
    }

    // 30s default: long enough for a user to answer the first-run Automation consent dialog (the
    // Apple Event blocks until they do), but still bounded so a wedged app can't stall forever.
    nonisolated static func run(_ script: String, timeout: TimeInterval = 30) async -> String {
        await runCapturingErrors(script, timeout: timeout).output
    }

    // Same, but also returns osascript's stderr (nil when empty) for callers that surface errors.
    nonisolated static func runCapturingErrors(_ script: String, timeout: TimeInterval = 30) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

                do {
                    try process.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    watchdog.cancel()
                    let error = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: Result(
                        output: String(data: outData, encoding: .utf8) ?? "",
                        error: (error?.isEmpty ?? true) ? nil : error
                    ))
                } catch {
                    watchdog.cancel()
                    continuation.resume(returning: Result(output: "", error: error.localizedDescription))
                }
            }
        }
    }
}
