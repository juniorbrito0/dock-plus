import SwiftUI

// Type a search or a web address and press Return: it opens in a new Google Chrome tab.
// The list button on the left shows Chrome's open tabs; picking one brings it to the front.
// Falls back to the default browser when Chrome isn't installed.
struct ChromeSearchWidget: DockWidgetView {
    @State private var query = ""
    @State private var showingTabs = false
    @State private var chrome = ChromeTabsService.shared
    init() {}

    private var width: CGFloat { Theme.Size.tileWidth(units: WidgetKind.chromeSearch.widthUnits) }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { showingTabs.toggle() } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 26, height: 26)
                    .background(Theme.Color.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Chrome tabs")
            .popover(isPresented: $showingTabs, arrowEdge: .top) {
                ChromeTabsList(chrome: chrome) { showingTabs = false }
                    .task { await chrome.refresh() }
            }

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

private struct ChromeTabsList: View {
    let chrome: ChromeTabsService
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Chrome Tabs")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Spacer(minLength: 0)
                if chrome.loading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("\(chrome.tabs.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            if !chrome.isRunning {
                hint("Chrome isn’t open", detail: "Search above to open it.")
            } else if chrome.tabs.isEmpty && !chrome.loading {
                hint("No tabs found", detail: "If this persists, allow Dock+ to control Chrome in System Settings ▸ Privacy ▸ Automation.")
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(chrome.tabs) { tab in
                            ChromeTabRow(tab: tab) {
                                chrome.focus(tab)
                                onPick()
                            }
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 460)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 320)
    }

    private func hint(_ title: String, detail: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }
}

private struct ChromeTabRow: View {
    let tab: ChromeTab
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.title.isEmpty ? tab.host : tab.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                    Text(tab.host)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 40)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovering ? Theme.Color.tileFillHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tab.url)
    }
}
