import Combine
import Foundation

enum AppFeature: String, Hashable {
    case petCustomization
}

@MainActor
final class FeatureEntitlementStore: ObservableObject {
    @Published private var unlockedFeatures: Set<AppFeature>

    init() {
        unlockedFeatures = [.petCustomization]
    }

    func isUnlocked(_ feature: AppFeature) -> Bool {
        unlockedFeatures.contains(feature)
    }
}
