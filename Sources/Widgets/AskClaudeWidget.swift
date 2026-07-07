import SwiftUI

struct AskClaudeWidget: DockWidgetView {
    @State private var query = ""
    @FocusState private var focused: Bool
    init() {}

    private var width: CGFloat { Theme.Size.tileWidth(units: WidgetKind.askClaude.widthUnits) }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)

            TextField("Ask Claude…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Color.textPrimary)
                .focused($focused)
                .onSubmit { submit() }

            if !trimmed.isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Color.accent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(width: width, height: Theme.Size.tile)
        .tileChrome()
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed),
              let url = URL(string: "claude://claude.ai/new?q=\(encoded)") else { return }
        NSWorkspace.shared.open(url)
        query = ""
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
