import SwiftUI

struct QuickActionsWidget: DockWidgetView {
    @State private var actions = QuickActionsService.shared

    init() {}

    private static let buttonSize = CGSize(width: 26, height: 22)
    private static let gap: CGFloat = 6

    private var rows: [GridItem] {
        let count = actions.enabledActions.count > 1 ? 2 : 1
        return Array(repeating: GridItem(.fixed(Self.buttonSize.height), spacing: Self.gap), count: count)
    }

    // Widen the tile by one button column for every two actions.
    private var widthUnits: CGFloat {
        let columns = CGFloat((actions.enabledActions.count + 1) / 2)
        let needed = columns * Self.buttonSize.width + max(0, columns - 1) * Self.gap
        let units = (needed + Theme.Spacing.md) / (Theme.Size.tile + Theme.Spacing.md)
        return max(WidgetKind.quickActions.widthUnits, units)
    }

    var body: some View {
        WidgetTile(widthUnits: widthUnits) {
            // Two rows that grow sideways, so every action stays inside the tile and clickable.
            LazyHGrid(rows: rows, spacing: Self.gap) {
                ForEach(actions.enabledActions) { action in
                    actionButton(symbol: action.symbol, help: action.title) {
                        actions.run(action)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { actions.load() }
    }

    private func actionButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: Self.buttonSize.width, height: Self.buttonSize.height)
                .background(Theme.Color.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
