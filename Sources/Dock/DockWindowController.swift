import SwiftUI
import AppKit

// A borderless, non-activating panel that can still become key when a control (a text field)
// needs it — so widgets like Ask Claude / 1Password accept typing without stealing app focus.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// Hosts the dock in a panel that floats just above the system Dock, stays on every Space,
// lifts out of the way when an auto-hidden Dock reveals, and resizes to its enabled widgets.
@MainActor
final class DockWindowController: NSObject, NSWindowDelegate {
    private let panel: KeyablePanel
    private let hosting: NSHostingController<DockView>

    override init() {
        hosting = NSHostingController(rootView: DockView())
        hosting.sizingOptions = [.intrinsicContentSize]

        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: Int(Theme.Size.barHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.delegate = self

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: .dockEdgeChanged, object: nil
        )

        DockVisibilityMonitor.shared.onChange = { [weak self] in self?.reposition() }
        DockVisibilityMonitor.shared.start()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        panel.orderFrontRegardless()
        reposition()
    }

    @objc private func screenChanged() { reposition() }

    func windowDidResize(_ notification: Notification) { reposition() }

    private func reposition() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let margin: CGFloat = 2
        let dockInset = DockVisibilityMonitor.shared.bottomInset

        let origin: NSPoint
        switch DockSettings.shared.edge {
        case .bottom:
            origin = NSPoint(x: visible.midX - size.width / 2, y: visible.minY + margin + dockInset)
        case .top:
            origin = NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - margin)
        case .left:
            origin = NSPoint(x: visible.minX + margin, y: visible.midY - size.height / 2)
        case .right:
            origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.midY - size.height / 2)
        }

        panel.setFrameOrigin(origin)
    }
}
