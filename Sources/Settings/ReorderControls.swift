import SwiftUI

// A widget in the "Enabled" list: drag grip, up/down arrows for people who don't think to drag,
// and a remove button.
struct EnabledWidgetRow: View {
    let kind: WidgetKind
    let settings: DockSettings

    var body: some View {
        let index = settings.enabledWidgets.firstIndex(of: kind) ?? 0
        let last = settings.enabledWidgets.count - 1
        HStack {
            DragHandle()
            Label(kind.title, systemImage: kind.symbol)
            Spacer()
            MoveButton(symbol: "chevron.up", help: "Move up", disabled: index == 0) {
                withAnimation { settings.move(from: [index], to: index - 1) }
            }
            MoveButton(symbol: "chevron.down", help: "Move down", disabled: index >= last) {
                withAnimation { settings.move(from: [index], to: index + 2) }
            }
            Button {
                settings.toggle(kind)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from dock")
        }
    }
}

// The ≡ grip that tells people a row can be dragged to reorder it.
struct DragHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 14)
            .help("Drag to reorder")
    }
}

struct MoveButton: View {
    let symbol: String
    let help: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.25 : 1)
        .help(help)
    }
}

struct ReorderHint: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "arrow.up.arrow.down")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
