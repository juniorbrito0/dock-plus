import EventKit

// EKEventStore.authorizationStatus(for:) keeps answering .notDetermined for the rest of the
// process after the user allows access in the system prompt; only a relaunch refreshes it.
// Remember grants made this session so Settings and the widgets update immediately.
@MainActor
enum EventKitAccess {
    private static var grantedThisSession: Set<EKEntityType> = []

    static func status(for type: EKEntityType) -> EKAuthorizationStatus {
        grantedThisSession.contains(type) ? .fullAccess : EKEventStore.authorizationStatus(for: type)
    }

    static func recordGrant(for type: EKEntityType) {
        grantedThisSession.insert(type)
    }
}
