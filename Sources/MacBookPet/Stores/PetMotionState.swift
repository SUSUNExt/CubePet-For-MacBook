import CoreGraphics
import Foundation

struct ExperienceGainEffect: Identifiable, Equatable {
    let id = UUID()
    let amount: Int
}

@MainActor
final class PetMotionState: ObservableObject {
    @Published var rotationDegrees: CGFloat = 0
    @Published var stretchX: CGFloat = 1
    @Published var stretchY: CGFloat = 1
    @Published var gazeOffset: CGSize = .zero
    @Published var feedMouthOpen: CGFloat = 0
    @Published var isGrabbed = false
    @Published private(set) var experienceGainEffect: ExperienceGainEffect?

    private var experienceGainTask: Task<Void, Never>?

    func showExperienceGain(_ amount: Int) {
        guard amount > 0 else { return }

        experienceGainTask?.cancel()
        experienceGainTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }

            let effect = ExperienceGainEffect(amount: amount)
            self?.experienceGainEffect = effect

            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled, self?.experienceGainEffect?.id == effect.id else { return }
            self?.experienceGainEffect = nil
        }
    }
}
