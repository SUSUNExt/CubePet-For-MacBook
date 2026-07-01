import Darwin
import Foundation

struct SystemMetricsSnapshot {
    var cpuUsage: Double = 0
    var memoryUsage: Double = 0
    var downloadBytesPerSecond: Double = 0
    var uploadBytesPerSecond: Double = 0
}

@MainActor
final class SystemMetricsMonitor {
    var onUpdate: ((SystemMetricsSnapshot) -> Void)?

    private var timer: Timer?
    private var previousCPUTicks: CPUTicks?
    private var previousNetworkTotals: NetworkTotals?
    private var previousNetworkSampleTime = ProcessInfo.processInfo.systemUptime

    func start() {
        stop()
        previousCPUTicks = readCPUTicks()
        previousNetworkTotals = readNetworkTotals()
        previousNetworkSampleTime = ProcessInfo.processInfo.systemUptime
        onUpdate?(SystemMetricsSnapshot(memoryUsage: readMemoryUsage()))

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let cpuTicks = readCPUTicks()
        let networkTotals = readNetworkTotals()
        let now = ProcessInfo.processInfo.systemUptime

        var snapshot = SystemMetricsSnapshot(memoryUsage: readMemoryUsage())

        if let previousCPUTicks, let cpuTicks {
            let usedDelta = cpuTicks.used >= previousCPUTicks.used ? cpuTicks.used - previousCPUTicks.used : 0
            let totalDelta = cpuTicks.total >= previousCPUTicks.total ? cpuTicks.total - previousCPUTicks.total : 0
            if totalDelta > 0 {
                snapshot.cpuUsage = Double(usedDelta) / Double(totalDelta)
            }
        }

        let elapsed = max(now - previousNetworkSampleTime, 0.001)
        if let previousNetworkTotals {
            let receivedDelta = networkTotals.received >= previousNetworkTotals.received
                ? networkTotals.received - previousNetworkTotals.received
                : 0
            let sentDelta = networkTotals.sent >= previousNetworkTotals.sent
                ? networkTotals.sent - previousNetworkTotals.sent
                : 0
            snapshot.downloadBytesPerSecond = Double(receivedDelta) / elapsed
            snapshot.uploadBytesPerSecond = Double(sentDelta) / elapsed
        }

        previousCPUTicks = cpuTicks
        previousNetworkTotals = networkTotals
        previousNetworkSampleTime = now
        onUpdate?(snapshot)
    }

    private func readCPUTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let ticks = withUnsafeBytes(of: info.cpu_ticks) { bytes in
            Array(bytes.bindMemory(to: natural_t.self)).map(UInt64.init)
        }
        guard ticks.count >= 4 else { return nil }

        let used = ticks[0] + ticks[1] + ticks[3]
        return CPUTicks(used: used, total: used + ticks[2])
    }

    private func readMemoryUsage() -> Double {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let internalPages = UInt64(statistics.internal_page_count)
        let purgeablePages = UInt64(statistics.purgeable_count)
        let nonPurgeableInternalPages = internalPages >= purgeablePages
            ? internalPages - purgeablePages
            : 0
        let usedPages = nonPurgeableInternalPages
            + UInt64(statistics.wire_count)
            + UInt64(statistics.compressor_page_count)
        let usedBytes = usedPages * UInt64(vm_kernel_page_size)
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        guard totalBytes > 0 else { return 0 }

        return min(Double(usedBytes) / Double(totalBytes), 1)
    }

    private func readNetworkTotals() -> NetworkTotals {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0, let firstAddress else {
            return NetworkTotals()
        }
        defer { freeifaddrs(firstAddress) }

        var totals = NetworkTotals()
        var currentAddress: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let address = currentAddress {
            defer { currentAddress = address.pointee.ifa_next }

            let interface = address.pointee
            guard
                let socketAddress = interface.ifa_addr,
                socketAddress.pointee.sa_family == UInt8(AF_LINK),
                interface.ifa_flags & UInt32(IFF_UP) != 0,
                interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                String(cString: interface.ifa_name).hasPrefix("en"),
                let dataPointer = interface.ifa_data
            else { continue }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            totals.received += UInt64(data.ifi_ibytes)
            totals.sent += UInt64(data.ifi_obytes)
        }

        return totals
    }

    deinit {
        timer?.invalidate()
    }
}

private struct CPUTicks {
    let used: UInt64
    let total: UInt64
}

private struct NetworkTotals {
    var received: UInt64 = 0
    var sent: UInt64 = 0
}
