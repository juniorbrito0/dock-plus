import SwiftUI

struct CalendarWidget: DockWidgetView {
    @State private var calendar = CalendarService.shared
    init() {}

    var body: some View {
        Button { calendar.openInCalendar(calendar.nextEvent) } label: {
            WidgetTile(widthUnits: WidgetKind.calendar.widthUnits) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    content(now: context.date)
                }
            }
        }
        .buttonStyle(.plain)
        .help(calendar.nextEvent == nil ? "Open Calendar" : "Open in Calendar")
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let event = calendar.nextEvent, let start = event.startDate {
            let urgency = Urgency(start: start, end: event.endDate, now: now)
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(urgency.tint.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(urgency.tint)
                        .frame(width: 9, height: 9)
                        .opacity(urgency.pulses ? 0.55 : 1)
                        .scaleEffect(urgency.pulses ? 1.5 : 1)
                        .animation(urgency.pulses
                                   ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                   : .default, value: urgency.pulses)
                }
                VStack(alignment: .leading, spacing: 2) {
                    // Two smaller lines, shrinking a little more if needed, so most titles fit whole.
                    Text(event.title ?? "Event")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(event.title ?? "")
                    Text(urgency.label)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(urgency.tint)
                }
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: Theme.Spacing.md) {
                TileGlyph(symbol: "calendar", tint: Theme.Color.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.authorized ? "No events" : "Enable access")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(calendar.authorized ? "Next 7 days clear" : "in Settings")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// Accent color for upcoming and in-progress events; amber under 30 min and pulsing red under 10 stay
// fixed as warnings whatever accent the user picks.
@MainActor
private struct Urgency {
    let tint: Color
    let label: String
    let pulses: Bool

    init(start: Date, end: Date?, now: Date) {
        let minutes = start.timeIntervalSince(now) / 60

        if minutes <= 0 {
            let ended = (end ?? start) < now
            tint = ended ? Theme.Color.textSecondary : Theme.Color.accent
            label = ended ? Self.relative(start) : "Now"
            pulses = false
            return
        }

        switch minutes {
        case ..<10:
            tint = Theme.Color.danger
            pulses = true
        case ..<30:
            tint = Theme.Color.warning
            pulses = false
        default:
            tint = Theme.Color.accent
            pulses = false
        }
        label = "in \(Self.countdown(minutes: minutes))"
    }

    private static func countdown(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return "\(total)m" }
        let hours = total / 60
        let mins = total % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    private static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}
