import SwiftUI

// A dock widget is a self-contained, live tile. Adding a new widget is: a new WidgetKind case,
// a view conforming to DockWidgetView, and a line in WidgetRegistry (DockView.swift).
enum WidgetKind: String, CaseIterable, Codable, Identifiable {
    case clockWeather
    case music
    case calendar
    case reminders
    case email
    case systemStats
    case battery
    case appLauncher
    case folders
    case bookmarks
    case emoji
    case askClaude
    case onePassword
    case quickActions
    case diaTabs
    case chromeSearch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clockWeather: "Clock & Weather"
        case .music: "Music"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .email: "Mail"
        case .systemStats: "System"
        case .battery: "Battery"
        case .appLauncher: "Apps"
        case .folders: "Folders"
        case .bookmarks: "Bookmarks"
        case .emoji: "Emoji"
        case .askClaude: "Ask Claude"
        case .onePassword: "1Password"
        case .quickActions: "Quick Actions"
        case .diaTabs: "Dia Tabs"
        case .chromeSearch: "Chrome Search"
        }
    }

    var symbol: String {
        switch self {
        case .clockWeather: "clock"
        case .music: "music.note"
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .email: "envelope"
        case .systemStats: "cpu"
        case .battery: "battery.100"
        case .appLauncher: "square.grid.2x2"
        case .folders: "folder"
        case .bookmarks: "bookmark"
        case .emoji: "face.smiling"
        case .askClaude: "sparkles"
        case .onePassword: "key"
        case .quickActions: "bolt"
        case .diaTabs: "safari"
        case .chromeSearch: "magnifyingglass"
        }
    }

    // Tiles may span more than one square (e.g. clock + date reads better as 1.6 wide).
    var widthUnits: CGFloat {
        switch self {
        case .clockWeather: 1.65
        case .music: 2.6
        case .email, .askClaude, .chromeSearch: 2.8
        case .emoji: 1.9
        case .calendar: 2.2
        case .appLauncher: 1.7
        case .systemStats: 1.4
        case .reminders, .battery, .folders, .bookmarks, .onePassword, .quickActions, .diaTabs: 1.0
        }
    }
}

@MainActor
protocol DockWidgetView: View {
    init()
}
