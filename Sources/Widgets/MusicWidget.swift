import SwiftUI

struct MusicWidget: DockWidgetView {
    @State private var music = MusicService.shared
    @State private var expanded = false
    init() {}

    private static let idleWidthUnits: CGFloat = 1

    var body: some View {
        Group {
            if music.hasTrack {
                nowPlaying
            } else {
                idle
            }
        }
        .frame(width: Theme.Size.tileWidth(units: music.hasTrack ? WidgetKind.music.widthUnits : Self.idleWidthUnits),
               height: Theme.Size.tile)
        .tileChrome()
        .animation(Theme.Motion.spring, value: music.hasTrack)
        .popover(isPresented: $expanded, arrowEdge: .top) {
            ExpandedMusicView(music: music)
        }
    }

    private var idle: some View {
        Button { music.openMusicApp() } label: {
            VStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Color.accent)
                    .symbolRenderingMode(.hierarchical)
                Text("Music")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var nowPlaying: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { expanded.toggle() } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Artwork(playing: music.isPlaying, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(music.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                        Text(music.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            TransportButton(symbol: music.isPlaying ? "pause.fill" : "play.fill", size: 13) {
                music.playPause()
            }
            TransportButton(symbol: "forward.fill", size: 12) { music.next() }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}

private struct ExpandedMusicView: View {
    @Bindable var music: MusicService

    var body: some View {
        VStack(spacing: 16) {
            Artwork(playing: music.isPlaying, size: 150)

            VStack(spacing: 3) {
                Text(music.hasTrack ? music.title : "Nothing playing")
                    .font(.system(size: 15, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(music.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if !music.album.isEmpty {
                    Text(music.album)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 24) {
                TransportButton(symbol: "backward.fill", size: 18) { music.previous() }
                TransportButton(symbol: music.isPlaying ? "pause.circle.fill" : "play.circle.fill", size: 40) {
                    music.playPause()
                }
                TransportButton(symbol: "forward.fill", size: 18) { music.next() }
            }

            if !music.source.isEmpty {
                Label(music.source, systemImage: "hifispeaker")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.Color.accentSoft, in: Capsule())
            }

            if !music.playlistTracks.isEmpty {
                Divider().padding(.horizontal, -4)
                playlist
            }
        }
        .padding(20)
        .frame(width: 240)
        .task { await music.loadPlaylist() }
    }

    private var playlist: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(music.playlistName, systemImage: "music.note.list")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(music.playlistTracks) { track in
                        TrackRow(track: track, isCurrent: track.name == music.title) {
                            music.play(track)
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
    }
}

private struct TrackRow: View {
    let track: MusicTrack
    let isCurrent: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                    .font(.system(size: 9))
                    .foregroundStyle(isCurrent ? Theme.Color.accent : Theme.Color.textSecondary)
                    .frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(track.name)
                        .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Theme.Color.accent : Theme.Color.textPrimary)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(hovering ? Theme.Color.tileFillHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct Artwork: View {
    let playing: Bool
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size > 60 ? 16 : 9, style: .continuous)
            .fill(LinearGradient(
                colors: [Theme.Color.accent.opacity(0.9), Theme.Color.accentSecondary.opacity(0.9)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: playing ? "waveform" : "music.note")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: playing && size > 60)
            )
    }
}

private struct TransportButton: View {
    let symbol: String
    var size: CGFloat = 14
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(Theme.Color.accent)
                .scaleEffect(hovering ? 1.15 : 1)
                .animation(Theme.Motion.quick, value: hovering)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
