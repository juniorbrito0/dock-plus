import Foundation
import Darwin

// Runs a helper tool as its own "responsible process" instead of as a child of Dock+.
//
// macOS attributes a child's privacy-sensitive access to the app that launched it. The 1Password
// CLI (`op`) talks to the 1Password app through 1Password's group container; launched normally from
// Dock+, that access is attributed to Dock+ (a different developer) and `op` silently finds no
// accounts. Terminals avoid this by "disclaiming" responsibility when they spawn a shell, via
// responsibility_spawnattrs_setdisclaim — looked up at runtime because it isn't in the public SDK.
enum DisclaimedSpawn {
    struct Result: Sendable {
        let out: String
        let err: String
        let status: Int32
    }

    private typealias SetDisclaim = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32

    nonisolated static func run(_ path: String, _ args: [String], timeout: TimeInterval = 60) -> Result? {
        var attr: posix_spawnattr_t?
        guard posix_spawnattr_init(&attr) == 0 else { return nil }
        defer { posix_spawnattr_destroy(&attr) }
        if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_spawnattrs_setdisclaim") {
            _ = unsafeBitCast(symbol, to: SetDisclaim.self)(&attr, 1)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, outPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, errPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        let argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        let envp: [UnsafeMutablePointer<CChar>?] = ProcessInfo.processInfo.environment
            .map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { envp.forEach { free($0) } }

        var pid: pid_t = 0
        guard posix_spawn(&pid, path, &actions, &attr, argv, envp) == 0 else { return nil }
        // Close our copies of the write ends so reads see EOF when the child exits.
        try? outPipe.fileHandleForWriting.close()
        try? errPipe.fileHandleForWriting.close()

        let watchdog = DispatchWorkItem { kill(pid, SIGTERM) }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

        // Drain stderr concurrently so a chatty child can't block on a full pipe.
        let errBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errBox.data = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        let errData = errBox.data

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        watchdog.cancel()
        let exitCode = (status & 0x7f) == 0 ? (status >> 8) & 0xff : -1
        return Result(out: String(data: outData, encoding: .utf8) ?? "",
                      err: String(data: errData, encoding: .utf8) ?? "",
                      status: exitCode)
    }
}

// Written once on a background queue and read only after the DispatchGroup wait, so the
// handoff is ordered even though the compiler can't prove it.
private final class DataBox: @unchecked Sendable {
    var data = Data()
}
