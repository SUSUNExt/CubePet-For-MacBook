import Combine
import Foundation

final class PetAgeStore: ObservableObject {
    private static let accumulatedRuntimeKey = "MacBookPet.accumulatedRuntime"

    @Published private(set) var accumulatedRuntime: TimeInterval

    private var sessionStartUptime: TimeInterval
    private var saveTimer: Timer?

    init() {
        accumulatedRuntime = UserDefaults.standard.double(forKey: Self.accumulatedRuntimeKey)
        sessionStartUptime = ProcessInfo.processInfo.systemUptime
    }

    var totalRuntime: TimeInterval {
        accumulatedRuntime + max(0, ProcessInfo.processInfo.systemUptime - sessionStartUptime)
    }

    func start() {
        guard saveTimer == nil else { return }

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.persist()
        }
        RunLoop.main.add(timer, forMode: .common)
        saveTimer = timer
    }

    func persist() {
        let now = ProcessInfo.processInfo.systemUptime
        accumulatedRuntime += max(0, now - sessionStartUptime)
        sessionStartUptime = now
        UserDefaults.standard.set(accumulatedRuntime, forKey: Self.accumulatedRuntimeKey)
    }

    func stopAndPersist() {
        persist()
        saveTimer?.invalidate()
        saveTimer = nil
    }
}
