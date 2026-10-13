import AppKit
import ApplicationServices

// Keeps other apps' windows clear of Dock+, the way macOS keeps windows above the system Dock.
// macOS has no public API for reserving screen space, so this watches windows through the
// Accessibility API and, once a window is created or a move/resize finishes, trims or nudges it
// out of the strip Dock+ occupies. People can still move and resize windows anywhere else.
@MainActor
final class WindowGuardService {
    static let shared = WindowGuardService()

    // The strip to keep clear, in Cocoa screen coordinates (origin bottom-left of the main display).
    private var reserved: NSRect?
    private var edge: DockEdge = .bottom
    private var observers: [pid_t: AXObserver] = [:]
    private var pending: [AXUIElement] = []
    private var settleTask: Task<Void, Never>?
    private var reflowTask: Task<Void, Never>?
    private var started = false

    private static let minimumHeight: CGFloat = 200
    private static let settleDelay: Duration = .milliseconds(350)

    private init() {}

    var isActive: Bool { DockSettings.shared.keepWindowsClear && AXIsProcessTrusted() }

    func start() {
        guard !started else { return }
        started = true
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appLaunched(_:)),
                           name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appTerminated(_:)),
                           name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        NSWorkspace.shared.runningApplications.forEach(observe)
    }

    // Called by the dock window whenever it settles in place. A nil strip (minimized) frees the space.
    func updateReservedArea(_ rect: NSRect?, edge: DockEdge) {
        let changed = rect != reserved || edge != self.edge
        reserved = rect
        self.edge = edge
        guard changed else { return }
        // The panel resizes in steps while minimizing/expanding; re-check windows once it settles.
        reflowTask?.cancel()
        reflowTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.applyToAllWindows()
        }
    }

    // Re-check every window, e.g. after the setting is switched on or Accessibility is granted.
    func applyToAllWindows() {
        guard isActive else { return }
        if observers.isEmpty { NSWorkspace.shared.runningApplications.forEach(observe) }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { continue }
            windows.forEach(constrain)
        }
    }

    @objc private func appLaunched(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        observe(app)
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let observer = observers.removeValue(forKey: app.processIdentifier) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func observe(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard AXIsProcessTrusted(), app.activationPolicy == .regular,
              pid != ProcessInfo.processInfo.processIdentifier, observers[pid] == nil else { return }

        var created: AXObserver?
        guard AXObserverCreate(pid, windowGuardCallback, &created) == .success, let observer = created else { return }
        let element = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXWindowMovedNotification, kAXWindowResizedNotification] {
            AXObserverAddNotification(observer, element, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    // Moves and resizes fire continuously while dragging; wait until the user lets go so we never
    // fight the pointer, then fix every window that changed.
    fileprivate func windowChanged(_ window: AXUIElement) {
        guard isActive else { return }
        if !pending.contains(where: { CFEqual($0, window) }) { pending.append(window) }
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard let self, !Task.isCancelled else { return }
            if NSEvent.pressedMouseButtons != 0 {
                if let last = self.pending.last { self.windowChanged(last) }
                return
            }
            let windows = self.pending
            self.pending.removeAll()
            windows.forEach(self.constrain)
        }
    }

    private func constrain(_ window: AXUIElement) {
        guard isActive, let reserved, let primary = NSScreen.screens.first,
              Self.isStandardWindow(window),
              var frame = Self.frame(of: window) else { return }

        // AX uses top-left origin coordinates; convert the strip and the usable area to match.
        let height = primary.frame.height
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(reserved) }) else { return }
        let stripTop = height - reserved.maxY
        let stripBottom = height - reserved.minY
        let usableTop = height - screen.visibleFrame.maxY
        let usableBottom = height - screen.visibleFrame.minY
        // Only windows on the same display as Dock+. Checking the window's centre in both directions
        // matters: a display stacked below this one shares its horizontal span, so a sideways-only
        // test would treat windows there as "under the dock" and push them back onto this display.
        let screenRect = CGRect(x: screen.frame.minX, y: height - screen.frame.maxY,
                                width: screen.frame.width, height: screen.frame.height)
        guard screenRect.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return }

        let original = frame
        switch edge {
        case .bottom:
            guard frame.maxY > stripTop else { return }
            if stripTop - frame.minY >= Self.minimumHeight {
                frame.size.height = stripTop - frame.minY
            } else {
                frame.origin.y = max(usableTop, stripTop - frame.height)
                frame.size.height = min(frame.height, stripTop - frame.origin.y)
            }
        case .top:
            guard frame.minY < stripBottom else { return }
            frame.origin.y = stripBottom
            if frame.maxY > usableBottom { frame.size.height = max(Self.minimumHeight, usableBottom - stripBottom) }
        }
        guard frame != original else { return }
        Self.setFrame(frame, of: window)
    }

    private static func isStandardWindow(_ window: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
        guard (subrole as? String) == (kAXStandardWindowSubrole as String) else { return false }
        var fullScreen: CFTypeRef?
        AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullScreen)
        return (fullScreen as? Bool) != true
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        return CGRect(origin: position, size: size)
    }

    private static func setFrame(_ frame: CGRect, of window: AXUIElement) {
        var position = frame.origin
        var size = frame.size
        // Position first so a shrinking window never briefly extends past the screen edge.
        if let value = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }
}

// AX observers deliver on the run loop they're attached to: the main one.
private func windowGuardCallback(_ observer: AXObserver, _ element: AXUIElement,
                                 _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    // Already on the main thread (see above), so handing these to the main actor can't race.
    nonisolated(unsafe) let pointer = refcon
    nonisolated(unsafe) let window = element
    MainActor.assumeIsolated {
        Unmanaged<WindowGuardService>.fromOpaque(pointer).takeUnretainedValue().windowChanged(window)
    }
}
