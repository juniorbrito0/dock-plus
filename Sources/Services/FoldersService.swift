import SwiftUI
import AppKit
import QuickLookThumbnailing

struct FavoriteFolder: Identifiable, Hashable {
    let id: String        // folder path
    let name: String
    let url: URL
    let icon: NSImage
}

struct FolderFile: Identifiable, Hashable {
    let id: String        // file path
    let name: String
    let url: URL
}

@MainActor
@Observable
final class FoldersService {
    static let shared = FoldersService()

    private(set) var folders: [FavoriteFolder] = []

    private let defaultsKey = "favoriteFolderPaths"
    private let fileLimit = 40
    private let thumbnails = NSCache<NSString, NSImage>()

    private init() {}

    func load() {
        let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        folders = stored.compactMap(makeFolder)
    }

    func add(_ url: URL) {
        guard !folders.contains(where: { $0.url == url }), let folder = makeFolder(path: url.path) else { return }
        folders.append(folder)
        persist()
    }

    func remove(_ folder: FavoriteFolder) {
        folders.removeAll { $0.id == folder.id }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // Directory enumeration + per-file displayName is disk I/O that stutters the dock on slow or
    // network volumes, so run it off the main actor and hand back a Sendable snapshot.
    func files(in folder: FavoriteFolder) async -> [FolderFile] {
        let url = folder.url
        let limit = fileLimit
        return await Task.detached {
            let fm = FileManager.default
            let urls = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            return urls
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .prefix(limit)
                .map { FolderFile(id: $0.path, name: fm.displayName(atPath: $0.path), url: $0) }
        }.value
    }

    func open(_ file: FolderFile) {
        NSWorkspace.shared.open(file.url)
    }

    func reveal(_ folder: FavoriteFolder) {
        NSWorkspace.shared.open(folder.url)
    }

    func thumbnail(for file: FolderFile) async -> NSImage {
        let key = file.id as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        let image = await generateThumbnail(for: file.url) ?? fallbackIcon(for: file.id)
        thumbnails.setObject(image, forKey: key)
        return image
    }

    private func generateThumbnail(for url: URL) async -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 40, height: 40),
            scale: scale,
            representationTypes: .all
        )
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return representation.nsImage
        } catch {
            return nil
        }
    }

    private func fallbackIcon(for path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 40, height: 40)
        return icon
    }

    private func persist() {
        UserDefaults.standard.set(folders.map(\.url.path), forKey: defaultsKey)
    }

    private func makeFolder(path: String) -> FavoriteFolder? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
        let url = URL(fileURLWithPath: path)
        let name = FileManager.default.displayName(atPath: path)
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 40, height: 40)
        return FavoriteFolder(id: path, name: name, url: url, icon: icon)
    }
}
