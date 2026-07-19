import Foundation
import SwiftUI

@MainActor
final class PetState: ObservableObject {
    @Published var expression: PetExpression = .calm
    @Published var isBlinking = false

    var allowsMouseGaze: Bool {
        expression.allowsMouseGaze
    }

    private var blinkTask: Task<Void, Never>?
    private var expressionResetTask: Task<Void, Never>?
    private var landingRecoveryTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var musicActivationTask: Task<Void, Never>?
    private var isMusicPlaying = false
    private var isMusicReactionActive = false

    func start() {
        blinkTask?.cancel()
        blinkTask = Task { [weak self] in
            while !Task.isCancelled {
                let delay = UInt64.random(in: 5_000_000_000...9_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                await self?.blink()
            }
        }
        scheduleIdleCycle()
    }

    func reactToClick(isHungry: Bool = false) {
        guard !isHungry else { return }

        expressionResetTask?.cancel()
        landingRecoveryTask?.cancel()
        scheduleIdleCycle()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            expression = .happy
        }

        expressionResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    self?.expression = self?.restingExpression ?? .calm
                }
            }
        }
    }

    func reactToGrab() {
        expressionResetTask?.cancel()
        landingRecoveryTask?.cancel()
        idleTask?.cancel()

        withAnimation(.spring(response: 0.16, dampingFraction: 0.68)) {
            expression = .scared
        }
    }

    func recoverAfterLanding() {
        guard expression == .scared else { return }

        landingRecoveryTask?.cancel()
        expression = restingExpression
        scheduleIdleCycle()
    }

    func reactToFeed() {
        expressionResetTask?.cancel()
        landingRecoveryTask?.cancel()
        scheduleIdleCycle()

        withAnimation(.easeInOut(duration: 0.18)) {
            expression = restingExpression
            isBlinking = false
        }
    }

    func resetExpression() {
        expressionResetTask?.cancel()
        landingRecoveryTask?.cancel()
        scheduleIdleCycle()
        withAnimation(.easeInOut(duration: 0.18)) {
            expression = restingExpression
        }
    }

    func setMusicPlaying(_ isPlaying: Bool) {
        guard isMusicPlaying != isPlaying else { return }

        isMusicPlaying = isPlaying
        musicActivationTask?.cancel()

        guard isPlaying else {
            isMusicReactionActive = false
            if expression == .listening {
                withAnimation(.easeInOut(duration: 0.28)) {
                    expression = .calm
                }
            }
            scheduleIdleCycle()
            return
        }

        musicActivationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.isMusicPlaying else { return }

                self.isMusicReactionActive = true
                self.idleTask?.cancel()
                guard self.expression != .scared else { return }

                withAnimation(.easeInOut(duration: 0.32)) {
                    self.expression = .listening
                    self.isBlinking = false
                }
            }
        }
    }

    private func blink() async {
        guard expression != .scared, expression != .sleeping else { return }

        withAnimation(.easeInOut(duration: 0.08)) {
            isBlinking = true
        }

        try? await Task.sleep(nanoseconds: 120_000_000)

        withAnimation(.easeInOut(duration: 0.12)) {
            isBlinking = false
        }
    }

    private func scheduleIdleCycle() {
        idleTask?.cancel()
        guard !isMusicReactionActive else { return }

        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 480_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self?.expression == .calm else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    self?.expression = .sleeping
                }
            }
        }
    }

    private var restingExpression: PetExpression {
        isMusicReactionActive ? .listening : .calm
    }

    deinit {
        blinkTask?.cancel()
        expressionResetTask?.cancel()
        landingRecoveryTask?.cancel()
        idleTask?.cancel()
        musicActivationTask?.cancel()
    }
}
