import SwiftUI
import EventKit
import CoreLocation
import ApplicationServices

enum PermissionState {
    case granted, denied, notDetermined, manual

    var label: String {
        switch self {
        case .granted: "Granted"
        case .denied: "Denied"
        case .notDetermined: "Not set"
        case .manual: "Manage"
        }
    }

    var tint: Color {
        switch self {
        case .granted: Theme.Color.positive
        case .denied: Theme.Color.danger
        case .notDetermined: Theme.Color.warning
        case .manual: Theme.Color.textSecondary
        }
    }
}

@MainActor
@Observable
final class PermissionsService: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionsService()

    private(set) var calendar: PermissionState = .notDetermined
    private(set) var reminders: PermissionState = .notDetermined
    private(set) var location: PermissionState = .notDetermined
    private(set) var accessibility: PermissionState = .notDetermined
    private(set) var automation: PermissionState = .manual   // macOS exposes no query API

    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()
    private var pollTask: Task<Void, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            DiagLog.log("locationManagerDidChangeAuthorization status=\(self.locationManager.authorizationStatus.rawValue)")
            self.refresh()
        }
    }

    func logLaunchDiagnostics() {
        DiagLog.log("launch bundle=\(Bundle.main.bundlePath) policy=\(NSApp.activationPolicy().rawValue) "
            + "cal=\(EKEventStore.authorizationStatus(for: .event).rawValue) "
            + "loc=\(locationManager.authorizationStatus.rawValue) ax=\(AXIsProcessTrusted())")
    }

    func refresh() {
        calendar = state(EKEventStore.authorizationStatus(for: .event))
        reminders = state(EKEventStore.authorizationStatus(for: .reminder))
        location = locationState(locationManager.authorizationStatus)
        accessibility = AXIsProcessTrusted() ? .granted : .notDetermined
    }

    // Accessibility and Automation grants happen in System Settings with no callback, so poll
    // while the settings window is open to reflect them live.
    func startPolling() {
        refresh()
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func requestCalendar() {
        // A pure accessory (LSUIElement) app cannot present a TCC prompt — the request just hangs
        // with no decision. Briefly promote to a regular foreground app so the system dialog can
        // present, then restore .accessory once the request resolves.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DiagLog.log("requestCalendar BEGIN status=\(EKEventStore.authorizationStatus(for: .event).rawValue) "
            + "policy=\(NSApp.activationPolicy().rawValue) active=\(NSApp.isActive)")
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled {
                DiagLog.log("requestCalendar STILL PENDING after 10s — the prompt never resolved (hang)")
                // The request can hang forever; restore .accessory so the app doesn't get stranded
                // as a Dock-icon regular app.
                NSApp.setActivationPolicy(.accessory)
            }
        }
        Task {
            // Let the .regular foreground transition settle before requesting, or EventKit may
            // refuse to present the prompt to a still-transitioning accessory app.
            try? await Task.sleep(for: .milliseconds(500))
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                DiagLog.log("requestCalendar RETURNED granted=\(granted) "
                    + "status=\(EKEventStore.authorizationStatus(for: .event).rawValue)")
            } catch {
                DiagLog.log("requestCalendar THREW \(error.localizedDescription)")
            }
            timeoutTask.cancel()
            NSApp.setActivationPolicy(.accessory)
            refresh()
        }
    }

    func requestReminders() {
        // Same accessory-app promotion as calendar so the TCC prompt can present.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DiagLog.log("requestReminders BEGIN status=\(EKEventStore.authorizationStatus(for: .reminder).rawValue) "
            + "policy=\(NSApp.activationPolicy().rawValue) active=\(NSApp.isActive)")
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled {
                DiagLog.log("requestReminders STILL PENDING after 10s — the prompt never resolved (hang)")
                NSApp.setActivationPolicy(.accessory)
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                DiagLog.log("requestReminders RETURNED granted=\(granted) "
                    + "status=\(EKEventStore.authorizationStatus(for: .reminder).rawValue)")
            } catch {
                DiagLog.log("requestReminders THREW \(error.localizedDescription)")
            }
            timeoutTask.cancel()
            NSApp.setActivationPolicy(.accessory)
            refresh()
            await RemindersService.shared.refresh()
        }
    }

    func requestLocation() {
        DiagLog.log("requestLocation BEGIN status=\(locationManager.authorizationStatus.rawValue) "
            + "policy=\(NSApp.activationPolicy().rawValue)")
        // WeatherService is already started at launch and re-fetches when authorization changes,
        // so there's nothing to kick off here — just request the grant.
        locationManager.requestWhenInUseAuthorization()
    }

    func promptAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func state(_ status: EKAuthorizationStatus) -> PermissionState {
        switch status {
        case .fullAccess, .authorized: .granted
        case .denied, .restricted, .writeOnly: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private func locationState(_ status: CLAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorizedAlways: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}
