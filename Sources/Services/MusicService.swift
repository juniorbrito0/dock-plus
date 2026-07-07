import Foundation
import AppKit

struct MusicTrack: Identifiable, Hashable {
    let name: String
    let artist: String
    var id: String { name + "|" + artist }
}

// Now-playing + transport for Music.app and Spotify via AppleScript. The system MediaRemote
// now-playing API is locked down on recent macOS, so scripting the players is the robust route.
@MainActor
@Observable
final class MusicService {
    static let shared = MusicService()

    private(set) var title = ""
    private(set) var artist = ""
    private(set) var album = ""
    private(set) var source = ""          // "Music" or "Spotify"
    private(set) var isPlaying = false
    var hasTrack: Bool { !title.isEmpty }

    private(set) var playlistName = ""
    private(set) var playlistTracks: [MusicTrack] = []

    private var task: Task<Void, Never>?

    private init() {}

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func playPause() { sendControl("playpause") }
    func next() { sendControl("next track") }
    func previous() { sendControl("previous track") }

    func openMusicApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
    }

    // The current playlist + its tracks (Music.app only; Spotify doesn't expose this reliably).
    func loadPlaylist() async {
        guard source == "Music",
              Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)).contains("com.apple.Music")
        else {
            playlistName = ""; playlistTracks = []
            return
        }
        let lines = (await AppleScriptRunner.run(Self.playlistScript)).split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first, !first.isEmpty else {
            playlistName = ""; playlistTracks = []
            return
        }
        playlistName = String(first)
        playlistTracks = lines.dropFirst().compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count == 2, !parts[0].isEmpty else { return nil }
            return MusicTrack(name: parts[0], artist: parts[1])
        }
    }

    func play(_ track: MusicTrack) {
        guard source == "Music" else { return }
        let safeName = track.name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Music\" to play (first track of current playlist whose name is \"\(safeName)\")"
        Task {
            _ = await AppleScriptRunner.run(script)
            await refresh()
        }
    }

    private func sendControl(_ command: String) {
        guard !source.isEmpty else { return }
        let script = "tell application \"\(source)\" to \(command)"
        Task {
            _ = await AppleScriptRunner.run(script)
            await refresh()
        }
    }

    private func refresh() async {
        // Only script a player that is actually running — a literal `tell application "X"` for an
        // uninstalled app fails to even compile, so we gate by running bundle IDs first.
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var outputs: [String] = []
        if running.contains("com.spotify.client") { outputs.append(await AppleScriptRunner.run(Self.spotifyScript)) }
        if running.contains("com.apple.Music") { outputs.append(await AppleScriptRunner.run(Self.musicScript)) }

        let parsed = outputs
            .map { $0.components(separatedBy: "\t") }
            .filter { $0.count == 5 }
        let line = parsed.first { $0[1] == "playing" } ?? parsed.first   // prefer a player that is playing

        guard let line else {
            title = ""; artist = ""; album = ""; source = ""; isPlaying = false
            return
        }
        source = line[0]
        isPlaying = line[1] == "playing"
        title = line[2]
        artist = line[3]
        album = line[4]
    }

    private static func script(for app: String) -> String {
        """
        tell application "\(app)"
            try
                if player state is stopped then return ""
                return "\(app)" & tab & (player state as text) & tab & (name of current track) ¬
                    & tab & (artist of current track) & tab & (album of current track)
            on error
                return ""
            end try
        end tell
        """
    }

    private static let musicScript = script(for: "Music")
    private static let spotifyScript = script(for: "Spotify")

    private static let playlistScript = """
    tell application "Music"
        try
            set pl to current playlist
            set out to (name of pl) & linefeed
            set n to 0
            repeat with t in (every track of pl)
                if n is 40 then exit repeat
                set out to out & (name of t) & tab & (artist of t) & linefeed
                set n to n + 1
            end repeat
            return out
        on error
            return ""
        end try
    end tell
    """
}
