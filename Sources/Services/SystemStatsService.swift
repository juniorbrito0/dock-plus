import Foundation
import Darwin

// Live CPU + memory pressure read straight from the mach kernel — no helper, no polling daemon.
@MainActor
@Observable
final class SystemStatsService {
    static let shared = SystemStatsService()

    private(set) var cpuUsage: Double = 0      // 0...1, total busy fraction
    private(set) var memoryUsed: Double = 0    // 0...1, fraction of physical RAM in use

    private var previousLoad: host_cpu_load_info?
    private var task: Task<Void, Never>?
    private let host = mach_host_self()

    private init() {}

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func sample() {
        cpuUsage = readCPU()
        memoryUsed = readMemory()
    }

    private func readCPU() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return cpuUsage }

        defer { previousLoad = info }
        guard let prev = previousLoad else { return cpuUsage }

        // Tick counters are UInt32 summed across cores and wrap after a few weeks of uptime;
        // wrapping subtraction keeps the delta correct instead of trapping on overflow.
        let user = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return cpuUsage }
        return (user + system + nice) / total
    }

    private func readMemory() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return memoryUsed }

        var size: vm_size_t = 0
        host_page_size(host, &size)
        let pageSize = Double(size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else { return memoryUsed }
        return (active + wired + compressed) / total
    }
}
