import SwiftUI

extension Notification.Name {
    static let dockEdgeChanged = Notification.Name("CoolDock.dockEdgeChanged")
}

enum DockEdge: String, CaseIterable, Codable, Identifiable {
    case bottom, top, left, right
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

@MainActor
@Observable
final class DockSettings {
    static let shared = DockSettings()

    var enabledWidgets: [WidgetKind] {
        didSet { persist(enabledWidgets, key: widgetsKey) }
    }
    var edge: DockEdge {
        didSet {
            UserDefaults.standard.set(edge.rawValue, forKey: edgeKey)
            NotificationCenter.default.post(name: .dockEdgeChanged, object: nil)
        }
    }

    static let defaultOrder: [WidgetKind] = [
        .clockWeather, .music, .calendar, .reminders, .email, .systemStats, .battery,
        .appLauncher, .folders, .bookmarks, .diaTabs, .emoji, .askClaude, .onePassword, .quickActions
    ]

    static let curatedDefault: [WidgetKind] = [
        .clockWeather, .music, .calendar, .reminders, .email, .systemStats, .battery,
        .appLauncher, .diaTabs, .emoji, .askClaude
    ]

    private let widgetsKey = "enabledWidgets"
    private let edgeKey = "dockEdge"
    private let seenKey = "seenWidgetKinds"

    private init() {
        let defaults = UserDefaults.standard
        // Only kinds never seen before are auto-added, so a kind the user disabled stays disabled.
        let seen = Set((defaults.array(forKey: seenKey) as? [String] ?? []).compactMap(WidgetKind.init(rawValue:)))
        // Decode as [String] then map through the initializer so one unknown/renamed rawValue drops
        // just that entry instead of throwing away the user's entire saved layout.
        if let data = defaults.data(forKey: widgetsKey),
           let raw = try? JSONDecoder().decode([String].self, from: data) {
            let decoded = raw.compactMap(WidgetKind.init(rawValue:))
            let known = Set(decoded)
            enabledWidgets = decoded + Self.defaultOrder.filter { !seen.contains($0) && !known.contains($0) }
        } else {
            enabledWidgets = Self.curatedDefault
        }
        edge = DockEdge(rawValue: defaults.string(forKey: edgeKey) ?? "") ?? .bottom
        defaults.set(WidgetKind.allCases.map(\.rawValue), forKey: seenKey)
        // didSet doesn't fire for assignments in init, so persist the merged list now — otherwise a
        // newly added widget kind shows once then vanishes on the next launch (seen but not saved).
        persist(enabledWidgets, key: widgetsKey)
    }

    func toggle(_ kind: WidgetKind) {
        if enabledWidgets.contains(kind) {
            enabledWidgets.removeAll { $0 == kind }
        } else {
            enabledWidgets.append(kind)
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        enabledWidgets.move(fromOffsets: source, toOffset: destination)
    }

    private func persist(_ widgets: [WidgetKind], key: String) {
        if let data = try? JSONEncoder().encode(widgets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
