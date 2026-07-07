import AppKit

// When the system Dock is set to auto-hide, it reveals as the pointer reaches the bottom edge.
// We track the pointer (reliable across macOS versions, unlike reading the Dock's private window)
// and report a bottom inset so Dock+ lifts to make room, then settles back when the pointer leaves.
@MainActor
@Observable
final class DockVisibilityMonitor {
    static let shared = DockVisibilityMonitor()

    private(set) var bottomInset: CGFloat = 0

    var onChange: (() -> Void)?

    private var task: Task<Void, Never>?
    // Cached once — the poll runs ~11×/second, so re-creating this suite per tick was pure churn.
    private let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    private init() {}

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func sample() {
        let target = targetInset()
        guard abs(target - bottomInset) > 0.5 else { return }
        bottomInset = target
        onChange?()
    }

    private func targetInset() -> CGFloat {
        let dock = dockDefaults
        let autohide = dock?.bool(forKey: "autohide") ?? false
        let orientation = dock?.string(forKey: "orientation") ?? "bottom"

        // Only the bottom Dock overlaps a bottom-anchored Dock+; a pinned Dock is already excluded
        // from the screen's visibleFrame, so no lift is needed there.
        guard autohide, orientation == "bottom", let screen = NSScreen.main else { return 0 }

        let mouse = NSEvent.mouseLocation
        guard screen.frame.contains(mouse) else { return 0 }

        let tile = dock?.double(forKey: "tilesize") ?? 0
        let dockHeight = (tile > 0 ? tile : 48) + 28
        let bottom = screen.frame.minY

        if bottomInset == 0 {
            return mouse.y <= bottom + 4 ? dockHeight : 0
        }
        // Stay lifted while the pointer is over the Dock or over the lifted Dock+ above it.
        let keepBand = bottom + dockHeight + Theme.Size.barHeight + 16
        return mouse.y <= keepBand ? dockHeight : 0
    }
}
