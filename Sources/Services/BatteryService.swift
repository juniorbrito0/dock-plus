import Foundation
import IOKit.ps

@MainActor
@Observable
final class BatteryService {
    static let shared = BatteryService()

    private(set) var level: Double = 1        // 0...1
    private(set) var isCharging = false
    private(set) var hasBattery = true

    private var task: Task<Void, Never>?

    private init() {}

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func sample() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            hasBattery = false
            return
        }

        hasBattery = true
        if let current = desc[kIOPSCurrentCapacityKey] as? Int,
           let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
            level = Double(current) / Double(max)
        }
        isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
    }
}
