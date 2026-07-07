import SwiftUI

struct EmailWidget: DockWidgetView {
    @State private var email = EmailService.shared
    @State private var expanded = false
    init() {}

    private var width: CGFloat { Theme.Size.tileWidth(units: WidgetKind.email.widthUnits) }

    private var headline: String {
        guard email.isMailRunning else { return "Mail not open" }
        guard let first = email.messages.first else { return "Inbox empty" }
        return first.sender
    }

    private var subline: String? {
        guard email.isMailRunning, email.messages.count > 1 else { return nil }
        return "+\(email.messages.count - 1) more"
    }

    var body: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: Theme.Spacing.md) {
                TileGlyph(symbol: "envelope.fill", tint: Theme.Color.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                    if let subline {
                        Text(subline)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: width, height: Theme.Size.tile, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .tileChrome()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $expanded, arrowEdge: .top) {
            InboxView(email: email)
        }
    }
}

private struct InboxView: View {
    @Bindable var email: EmailService

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Inbox", systemImage: "envelope.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)

            if !email.isMailRunning {
                Text("Mail not open")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if email.messages.isEmpty {
                Text("Inbox empty")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(email.messages) { message in
                    MessageRow(email: email, message: message)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 320, alignment: .leading)
    }
}

private struct MessageRow: View {
    let email: EmailService
    let message: EmailItem
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { email.activateMail() } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(message.sender)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                    Text(message.subject)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hovering {
                RowAction(symbol: "clock.badge") {
                    Task { await email.snooze(message) }
                }
                .help("Snooze (Remind Me)")
                RowAction(symbol: "archivebox") {
                    Task { await email.archive(message) }
                }
                RowAction(symbol: "trash") {
                    Task { await email.delete(message) }
                }
            }
        }
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
    }
}

private struct RowAction: View {
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovering ? Theme.Color.accent : Theme.Color.textSecondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.tile / 2, style: .continuous)
                        .fill(hovering ? Theme.Color.tileFillHover : Theme.Color.tileFill)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
