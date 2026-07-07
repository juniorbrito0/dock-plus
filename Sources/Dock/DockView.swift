import SwiftUI

// The glass bar itself: a vibrancy-backed capsule hosting the enabled widget tiles, or a slim
// handle when minimized.
struct DockView: View {
    @State private var settings = DockSettings.shared
    @State private var chrome = DockChrome.shared
    @State private var contentWidth: CGFloat = 0

    // Never let the bar spill off the screen — cap it and scroll the tiles inside.
    private var maxBarWidth: CGFloat {
        (NSScreen.main?.visibleFrame.width ?? 1440) - Theme.Spacing.lg * 2 - 24
    }

    var body: some View {
        Group {
            if chrome.minimized {
                MinimizedHandle { setMinimized(false) }
                    .fixedSize()
            } else {
                bar
            }
        }
        .padding(Theme.Spacing.lg)
    }

    private var overflowing: Bool { contentWidth > maxBarWidth && contentWidth > 0 }

    @ViewBuilder
    private var bar: some View {
        Group {
            if overflowing {
                ScrollView(.horizontal, showsIndicators: false) { tiles }
                    .frame(width: maxBarWidth, height: Theme.Size.barHeight)
            } else {
                tiles.fixedSize()
            }
        }
        .onPreferenceChange(BarWidthKey.self) { contentWidth = $0 }
        .background(
            // Frame runs 60% more transparent: the frosted panel and its tint both drop to 40%.
            ZStack {
                VisualEffectView(material: .hudWindow)
                    .opacity(0.4)
                RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
                    .fill(Color.black.opacity(0.072))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }

    private var tiles: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(settings.enabledWidgets) { kind in
                WidgetRegistry.view(for: kind)
            }
            MinimizeButton { setMinimized(true) }
        }
        .padding(Theme.Spacing.md)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: BarWidthKey.self, value: geo.size.width)
            }
        )
        .background(
            // Clicking the bar anywhere that isn't a card minimizes Dock+.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { setMinimized(true) }
        )
    }

    private func setMinimized(_ value: Bool) {
        withAnimation(Theme.Motion.spring) { chrome.minimized = value }
    }
}

// Intentionally low-key: a faint grip at the trailing edge that brightens only on hover.
private struct MinimizeButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.compact.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.textSecondary)
                .opacity(hovering ? 0.75 : 0.22)
                .frame(width: 14, height: Theme.Size.tile)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Minimize Dock+")
        .animation(Theme.Motion.quick, value: hovering)
    }
}

private struct MinimizedHandle: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 46, height: 30)
                .background(
                    ZStack {
                        VisualEffectView(material: .hudWindow)
                        Color.black.opacity(0.18)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .scaleEffect(hovering ? 1.06 : 1)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Show Dock+")
        .animation(Theme.Motion.spring, value: hovering)
    }
}

private struct BarWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum WidgetRegistry {
    @MainActor @ViewBuilder
    // swiftlint:disable:next cyclomatic_complexity
    static func view(for kind: WidgetKind) -> some View {
        switch kind {
        case .clockWeather: ClockWeatherWidget()
        case .music: MusicWidget()
        case .calendar: CalendarWidget()
        case .reminders: RemindersWidget()
        case .email: EmailWidget()
        case .systemStats: SystemStatsWidget()
        case .battery: BatteryWidget()
        case .appLauncher: AppLauncherWidget()
        case .folders: FoldersWidget()
        case .bookmarks: BookmarksWidget()
        case .emoji: EmojiWidget()
        case .askClaude: AskClaudeWidget()
        case .onePassword: OnePasswordWidget()
        case .quickActions: QuickActionsWidget()
        case .diaTabs: DiaTabsWidget()
        }
    }
}
