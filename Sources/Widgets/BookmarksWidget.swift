import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BookmarksWidget: DockWidgetView {
    @State private var bookmarks = BookmarksService.shared
    @State private var expanded = false
    @State private var isTargeted = false
    init() {}

    var body: some View {
        WidgetTile(widthUnits: WidgetKind.bookmarks.widthUnits) {
            Button { expanded.toggle() } label: {
                VStack(spacing: 6) {
                    Image(systemName: WidgetKind.bookmarks.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isTargeted ? Theme.Color.accent : Theme.Color.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("\(bookmarks.saved.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .strokeBorder(Theme.Color.accent, lineWidth: isTargeted ? 2 : 0)
                .animation(Theme.Motion.quick, value: isTargeted)
        )
        .onDrop(of: [.url, .text], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .popover(isPresented: $expanded, arrowEdge: .top) {
            BookmarksListView(bookmarks: bookmarks)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in bookmarks.add(url) }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                handled = true
                _ = provider.loadObject(ofClass: String.self) { string, _ in
                    guard let string, let url = Self.url(from: string) else { return }
                    Task { @MainActor in bookmarks.add(url) }
                }
            }
        }
        return handled
    }

    nonisolated private static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }
}

private struct BookmarksListView: View {
    @Bindable var bookmarks: BookmarksService

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if bookmarks.saved.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("Drop links here")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
            } else {
                ForEach(bookmarks.saved) { bookmark in
                    BookmarkRow(bookmark: bookmark) {
                        if let url = bookmark.url { NSWorkspace.shared.open(url) }
                    } onRemove: {
                        bookmarks.remove(bookmark)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 260)
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onOpen: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Color.accent)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bookmark.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                    Text(bookmark.host)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .fill(hovering ? Theme.Color.tileFillHover : Color.clear)
        )
        .onHover { hovering = $0 }
    }
}
