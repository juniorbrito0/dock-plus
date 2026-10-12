import SwiftUI

// Type a search or a web address and press Return: it opens in a new Google Chrome tab.
// Falls back to the default browser when Chrome isn't installed.
struct ChromeSearchWidget: DockWidgetView {
    @State private var query = ""
    init() {}

    private var width: CGFloat { Theme.Size.tileWidth(units: WidgetKind.chromeSearch.widthUnits) }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)

            TextField("Search or type a URL…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Color.textPrimary)
                .onSubmit { submit() }

            if !trimmed.isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Color.accent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open in Chrome")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(width: width, height: Theme.Size.tile)
        .tileChrome()
    }

    private func submit() {
        guard let url = Self.destination(for: trimmed) else { return }
        let workspace = NSWorkspace.shared
        if let chrome = workspace.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            workspace.open([url], withApplicationAt: chrome, configuration: configuration)
        } else {
            workspace.open(url)
        }
        query = ""
    }

    // "github.com", "localhost:3000" or "https://…" opens directly; anything else becomes a Google search.
    static func destination(for input: String) -> URL? {
        guard !input.isEmpty else { return nil }
        let looksLikeAddress = !input.contains(" ") && input.contains(".")
            && !input.hasSuffix(".") && !input.hasPrefix(".")
        if input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://") {
            return URL(string: input)
        }
        if input.lowercased().hasPrefix("localhost"), !input.contains(" ") {
            return URL(string: "http://\(input)")
        }
        if looksLikeAddress, let url = URL(string: "https://\(input)"), url.host != nil {
            return url
        }
        guard let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) else {
            return nil
        }
        return URL(string: "https://www.google.com/search?q=\(encoded)")
    }
}
