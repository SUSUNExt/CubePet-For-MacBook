import Combine
import Foundation

@MainActor
final class PetHungerStore: ObservableObject {
    static let maximumSatiety = 100
    static let hungryThreshold = 25

    private static let satietyKey = "MacBookPet.petSatiety"
    private static let lastUpdatedKey = "MacBookPet.petSatietyLastUpdated"
    private static let decayPerHour = 8.0

    @Published private(set) var satiety: Int

    var onChange: (() -> Void)?

    private var lastUpdated: Date
    private var timer: Timer?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        if defaults.object(forKey: Self.satietyKey) == nil {
            satiety = Self.maximumSatiety
        } else {
            satiety = Self.clamped(defaults.integer(forKey: Self.satietyKey))
        }
        lastUpdated = defaults.object(forKey: Self.lastUpdatedKey) as? Date ?? now
        refresh(now: now)
    }

    var satietyFraction: Double {
        Double(satiety) / Double(Self.maximumSatiety)
    }

    var isHungry: Bool {
        satiety <= Self.hungryThreshold
    }

    func start() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        refresh()
    }

    @discardableResult
    func feed(_ food: FoodDefinition, now: Date = Date()) -> Int {
        refresh(now: now)

        let oldSatiety = satiety
        satiety = Self.clamped(satiety + food.satiety)
        lastUpdated = now
        persist()

        let gainedSatiety = satiety - oldSatiety
        if gainedSatiety > 0 {
            onChange?()
        }
        return gainedSatiety
    }

    func refresh(now: Date = Date()) {
        let oldSatiety = satiety
        applyDecay(now: now)
        persist()

        if satiety != oldSatiety {
            onChange?()
        }
    }

    private func applyDecay(now: Date) {
        let elapsed = max(0, now.timeIntervalSince(lastUpdated))
        guard elapsed > 0 else { return }

        let decay = Int(floor((elapsed / 3_600) * Self.decayPerHour))
        guard decay > 0 else { return }

        satiety = Self.clamped(satiety - decay)
        lastUpdated = now
    }

    private func persist() {
        defaults.set(satiety, forKey: Self.satietyKey)
        defaults.set(lastUpdated, forKey: Self.lastUpdatedKey)
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 0), maximumSatiety)
    }
}
