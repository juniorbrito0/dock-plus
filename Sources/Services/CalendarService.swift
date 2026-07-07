import Foundation
import EventKit

// A Sendable snapshot of the fields the widget needs, so the (potentially slow) EventKit query
// can run off the main actor without carrying a non-Sendable EKEvent across the boundary.
struct CalendarEvent: Sendable, Equatable {
    let title: String?
    let startDate: Date?
    let endDate: Date?
}

@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    private(set) var nextEvent: CalendarEvent?
    private(set) var authorized = false

    private var task: Task<Void, Never>?

    private init() {}

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await self?.refresh()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func refresh() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorized = status == .fullAccess || status == .authorized
        guard authorized else { nextEvent = nil; return }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        // events(matching:) is synchronous and can be slow across many calendars — run it off-main.
        // A fresh EKEventStore in the task reads the same process-wide authorization.
        nextEvent = await Task.detached {
            let store = EKEventStore()
            let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
            return store.events(matching: predicate)
                .filter { !$0.isAllDay && ($0.endDate ?? now) > now }
                .sorted { ($0.startDate ?? now) < ($1.startDate ?? now) }
                .first
                .map { CalendarEvent(title: $0.title, startDate: $0.startDate, endDate: $0.endDate) }
        }.value
    }
}
