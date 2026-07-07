import SwiftUI

struct AppLauncherWidget: DockWidgetView {
    @State private var apps = AppsService.shared
    init() {}

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(apps.favorites) { app in
                AppIconButton(app: app) { apps.launch(app) }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: Theme.Size.tile)
        .tileChrome()
    }
}

private struct AppIconButton: View {
    let app: FavoriteApp
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 38, height: 38)
                .scaleEffect(hovering ? 1.18 : 1)
                .animation(Theme.Motion.spring, value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(app.name)
    }
}
