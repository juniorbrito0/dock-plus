import Foundation
import EventKit

// A Sendable snapshot of an EKReminder so fetch results can cross the EventKit completion
// boundary safely. Actions re-resolve the live EKReminder by id on the main actor.
struct ReminderItem: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let due: Date?

    var isOverdue: Bool {
        guard let due else { return false }
        return due < Date()
    }
}

// A reminder list (EKCalendar) the user can scope the widget to.
struct ReminderList: Identifiable, Sendable, Equatable {
    let id: String        // calendar identifier
    let title: String
}

// Which reminders the widget shows. "today" is a smart filter (due today or overdue, across all
// lists); "all" shows every incomplete reminder; otherwise it's a specific list's identifier.
enum ReminderScope: Equatable {
    case today
    case all
    case list(String)

    var storageValue: String {
        switch self {
        case .today: "today"
        case .all: "all"
        case .list(let id): id
        }
    }

    init(storageValue: String) {
        switch storageValue {
        case "today": self = .today
        case "all", "": self = .all
        default: self = .list(storageValue)
        }
    }
}

@MainActor
@Observable
final class RemindersService {
    static let shared = RemindersService()

    private(set) var reminders: [ReminderItem] = []
    private(set) var lists: [ReminderList] = []
    private(set) var authorized = false

    var scope: ReminderScope {
        didSet {
            UserDefaults.standard.set(scope.storageValue, forKey: scopeKey)
            Task { await refresh() }
        }
    }

    private let store = EKEventStore()
    private let scopeKey = "remindersScope"
    private var task: Task<Void, Never>?
    private var refreshing = false
    private var refreshPending = false

    private init() {
        let stored = UserDefaults.standard.string(forKey: scopeKey) ?? "today"
        scope = ReminderScope(storageValue: stored)
    }

    func start() {
        guard task == nil else { return }
        Task { await refresh() }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.refresh()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    // Coalesce overlapping refreshes (30s timer, scope switch, add/complete/reschedule): only one
    // fetch runs at a time, and any request that arrives mid-flight re-runs once at the end so the
    // latest state always wins and no needed refresh is dropped.
    func refresh() async {
        if refreshing { refreshPending = true; return }
        refreshing = true
        defer { refreshing = false }
        repeat {
            refreshPending = false
            await performRefresh()
        } while refreshPending
    }

    private func performRefresh() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        authorized = status == .fullAccess || status == .authorized
        guard authorized else { reminders = []; lists = []; return }

        let allCalendars = store.calendars(for: .reminder)
        lists = allCalendars
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        // Snapshot the scope once so an in-flight fetch is filtered against the scope it was issued
        // for, even if the user switches lists mid-refresh.
        let currentScope = scope

        // Scope a specific list at the query level; Today/All fetch everything, then filter below.
        let calendars: [EKCalendar]?
        if case .list(let id) = currentScope {
            calendars = allCalendars.filter { $0.calendarIdentifier == id }
        } else {
            calendars = nil
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: calendars)
        let items: [ReminderItem] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { @Sendable fetched in
                let mapped = (fetched ?? []).map {
                    ReminderItem(id: $0.calendarItemIdentifier,
                                 title: $0.title ?? "",
                                 due: $0.dueDateComponents.flatMap(Calendar.current.date(from:)))
                }
                continuation.resume(returning: mapped)
            }
        }
        let scoped = currentScope == .today ? items.filter(Self.isToday) : items
        reminders = scoped.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    // Mirrors Apple's "Today" smart list: anything due today or already overdue.
    private static func isToday(_ item: ReminderItem) -> Bool {
        guard let due = item.due else { return false }
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        guard let endOfToday else { return false }
        return due < endOfToday
    }

    func complete(_ item: ReminderItem) {
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
        Task { await refresh() }
    }

    func add(title: String, due: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let calendar = store.defaultCalendarForNewReminders() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = trimmed
        reminder.calendar = calendar
        if let due { reminder.dueDateComponents = Self.components(from: due) }
        try? store.save(reminder, commit: true)
        Task { await refresh() }
    }

    func reschedule(_ item: ReminderItem, to date: Date) {
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.dueDateComponents = Self.components(from: date)
        try? store.save(reminder, commit: true)
        Task { await refresh() }
    }

    private static func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }
}
