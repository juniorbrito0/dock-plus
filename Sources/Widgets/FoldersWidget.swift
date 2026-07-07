import SwiftUI
import AppKit

struct FoldersWidget: DockWidgetView {
    @State private var folders = FoldersService.shared
    @State private var openFolder: FavoriteFolder?
    init() {}

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(folders.folders) { folder in
                FolderIconButton(
                    folder: folder,
                    onTap: { openFolder = openFolder?.id == folder.id ? nil : folder },
                    onDoubleTap: {
                        openFolder = nil
                        folders.reveal(folder)
                    }
                )
                .popover(isPresented: popoverBinding(for: folder), arrowEdge: .top) {
                    FolderContentsView(folder: folder, service: folders)
                }
            }
            AddFolderButton(action: presentOpenPanel)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: Theme.Size.tile)
        .tileChrome()
        .onAppear { folders.load() }
    }

    private func popoverBinding(for folder: FavoriteFolder) -> Binding<Bool> {
        Binding(
            get: { openFolder?.id == folder.id },
            set: { if !$0 { openFolder = nil } }
        )
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            folders.add(url)
        }
    }
}

private struct FolderIconButton: View {
    let folder: FavoriteFolder
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: folder.icon)
                .resizable()
                .frame(width: 36, height: 36)
                .scaleEffect(hovering ? 1.16 : 1)
                .animation(Theme.Motion.spring, value: hovering)
            Text(folder.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 54)
        }
        .contentShape(Rectangle())
        // Double-click opens the folder in Finder; a single click toggles the contents popover.
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(count: 1, perform: onTap)
        .onHover { hovering = $0 }
        .help("\(folder.name) — double-click to open in Finder")
    }
}

private struct AddFolderButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.Color.accentSoft)
                )
                .scaleEffect(hovering ? 1.12 : 1)
                .animation(Theme.Motion.spring, value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add folder")
    }
}

private struct FolderContentsView: View {
    let folder: FavoriteFolder
    let service: FoldersService
    @State private var files: [FolderFile] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(nsImage: folder.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)

            if files.isEmpty {
                Text("Empty folder")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.lg)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(files) { file in
                            FileRow(file: file, service: service) { service.open(file) }
                        }
                    }
                }
                .frame(minHeight: 220, maxHeight: 520)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 300)
        .task { files = await service.files(in: folder) }
    }
}

private struct FileRow: View {
    let file: FolderFile
    let service: FoldersService
    let action: () -> Void
    @State private var thumbnail: NSImage?
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.Color.tileFill)
                    }
                }
                .frame(width: 30, height: 30)

                Text(file.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 38)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovering ? Theme.Color.tileFillHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .task { thumbnail = await service.thumbnail(for: file) }
    }
}
