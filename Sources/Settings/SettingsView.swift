import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var settings = DockSettings.shared
    @State private var apps = AppsService.shared
    @State private var permissions = PermissionsService.shared
    @State private var bookmarks = BookmarksService.shared
    @State private var folders = FoldersService.shared
    @State private var quickActions = QuickActionsService.shared
    @State private var loginItem = LoginItemService.shared

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gearshape") }
                widgetsTab
                    .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
                contentTab
                    .tabItem { Label("Content", systemImage: "tray.full") }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 400, height: 620)
        .onAppear {
            permissions.startPolling()
            bookmarks.load()
            folders.load()
            quickActions.load()
        }
        .onDisappear { permissions.stopPolling() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.Color.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Dock+").font(.title2).bold()
                Text("Your smart second Dock").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Permissions") {
                    VStack(spacing: 8) {
                        PermissionRow(name: "Calendar", detail: "Upcoming events",
                                      state: permissions.calendar,
                                      primary: permissions.calendar == .granted ? "Settings" : "Grant") {
                            permissions.calendar == .granted
                                ? permissions.openSettings("Privacy_Calendars")
                                : permissions.requestCalendar()
                        }
                        PermissionRow(name: "Reminders", detail: "Reminders widget",
                                      state: permissions.reminders,
                                      primary: permissions.reminders == .granted ? "Settings" : "Grant") {
                            permissions.reminders == .granted
                                ? permissions.openSettings("Privacy_Reminders")
                                : permissions.requestReminders()
                        }
                        PermissionRow(name: "Location", detail: "Local weather",
                                      state: permissions.location,
                                      primary: permissions.location == .granted ? "Settings" : "Grant") {
                            permissions.location == .granted
                                ? permissions.openSettings("Privacy_LocationServices")
                                : permissions.requestLocation()
                        }
                        PermissionRow(name: "Automation", detail: "Music & Mail widgets",
                                      state: permissions.automation, primary: "Settings") {
                            permissions.openSettings("Privacy_Automation")
                        }
                        PermissionRow(name: "Accessibility", detail: "Emoji paste into apps",
                                      state: permissions.accessibility,
                                      primary: permissions.accessibility == .granted ? "Settings" : "Grant") {
                            permissions.accessibility == .granted
                                ? permissions.openSettings("Privacy_Accessibility")
                                : permissions.promptAccessibility()
                        }
                        Button("No prompt? Open System Settings ▸ Privacy") {
                            permissions.openSettings("Privacy")
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                        .padding(.top, 2)
                    }
                }

                section("Dock position") {
                    Picker("", selection: $settings.edge) {
                        ForEach(DockEdge.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                section("Startup") {
                    Toggle("Start Dock+ automatically at login", isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    ))
                }

                section("Favorite apps") {
                    HStack {
                        Text("\(apps.favorites.count) apps in launcher — manage in the Content tab")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Add App…") { pickApp() }
                    }
                }

                Text("An app by brito.ai · © 2026")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(8)
        }
    }

    private var widgetsTab: some View {
        List {
            Section("Enabled") {
                ForEach(settings.enabledWidgets) { kind in
                    enabledRow(kind)
                }
                .onMove(perform: settings.move)
            }
            if !disabledWidgets.isEmpty {
                Section("Available") {
                    ForEach(disabledWidgets) { kind in
                        availableRow(kind)
                    }
                }
            }
        }
    }

    private var contentTab: some View {
        List {
            Section("Favorite Apps") {
                ForEach(apps.favorites) { app in
                    appRow(app)
                }
                .onMove(perform: apps.move)
                Button {
                    pickApp()
                } label: {
                    Label("Add App…", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.Color.accent)
                }
                .buttonStyle(.plain)
            }

            Section("Bookmarks") {
                if bookmarks.saved.isEmpty {
                    emptyRow("No bookmarks yet")
                } else {
                    ForEach(bookmarks.saved) { bookmark in
                        bookmarkRow(bookmark)
                    }
                    .onMove(perform: bookmarks.move)
                }
            }

            Section("Folders") {
                if folders.folders.isEmpty {
                    emptyRow("No folders yet")
                } else {
                    ForEach(folders.folders) { folder in
                        folderRow(folder)
                    }
                    .onMove(perform: folders.move)
                }
            }

            Section("Quick Actions") {
                ForEach(quickActions.enabledActions) { action in
                    quickActionRow(action, enabled: true)
                }
                .onMove(perform: quickActions.move)
                ForEach(disabledActions) { action in
                    quickActionRow(action, enabled: false)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2).bold()
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var disabledWidgets: [WidgetKind] {
        WidgetKind.allCases.filter { !settings.enabledWidgets.contains($0) }
    }

    private var disabledActions: [QuickAction] {
        quickActions.available.filter { !quickActions.enabledIDs.contains($0.id) }
    }

    private func enabledRow(_ kind: WidgetKind) -> some View {
        HStack {
            Label(kind.title, systemImage: kind.symbol)
            Spacer()
            Button {
                settings.toggle(kind)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func availableRow(_ kind: WidgetKind) -> some View {
        HStack {
            Label(kind.title, systemImage: kind.symbol)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                settings.toggle(kind)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Theme.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func appRow(_ app: FavoriteApp) -> some View {
        HStack {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 18, height: 18)
            Text(app.name).font(.system(size: 13))
            Spacer()
            Button {
                apps.remove(app)
            } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(bookmark.title).font(.system(size: 13, weight: .medium))
                Text(bookmark.host).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                bookmarks.remove(bookmark)
            } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func folderRow(_ folder: FavoriteFolder) -> some View {
        HStack {
            Image(nsImage: folder.icon)
                .resizable()
                .frame(width: 18, height: 18)
            Text(folder.name).font(.system(size: 13))
            Spacer()
            Button {
                folders.remove(folder)
            } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func quickActionRow(_ action: QuickAction, enabled: Bool) -> some View {
        HStack {
            Label(action.title, systemImage: action.symbol)
                .foregroundStyle(enabled ? .primary : .secondary)
            Spacer()
            Button {
                quickActions.toggle(id: action.id)
            } label: {
                Image(systemName: enabled ? "minus.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(enabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.Color.accent))
            }
            .buttonStyle(.plain)
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            apps.add(url)
        }
    }
}

private struct PermissionRow: View {
    let name: String
    let detail: String
    let state: PermissionState
    let primary: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(state.tint).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(state.tint)
            if state != .granted {
                Button(primary, action: action)
                    .controlSize(.small)
            } else {
                Button(primary, action: action)
                    .controlSize(.small)
                    .opacity(0.6)
            }
        }
    }
}
