import SwiftUI

struct SleepBubblesView: View {
    let date: Date

    private let bubbles: [SleepBubble] = [
        SleepBubble(id: 0, delay: 3.5, duration: 2.35, cycle: 42.0, diameter: 27, drift: -5, rise: 82),
        SleepBubble(id: 1, delay: 8.5, duration: 2.75, cycle: 42.0, diameter: 32, drift: 8, rise: 92),
        SleepBubble(id: 2, delay: 15.8, duration: 2.20, cycle: 42.0, diameter: 29, drift: 2, rise: 86),
        SleepBubble(id: 3, delay: 24.6, duration: 2.60, cycle: 42.0, diameter: 30, drift: -8, rise: 90),
        SleepBubble(id: 4, delay: 30.3, duration: 2.45, cycle: 42.0, diameter: 28, drift: 5, rise: 84),
        SleepBubble(id: 5, delay: 39.2, duration: 2.35, cycle: 42.0, diameter: 31, drift: -2, rise: 88)
    ]

    var body: some View {
        ZStack {
            ForEach(bubbles) { bubble in
                bubbleView(bubble)
            }
        }
        .frame(width: PetMetrics.canvasWidth, height: PetMetrics.canvasHeight)
    }

    private func bubbleView(_ bubble: SleepBubble) -> some View {
        let progress = bubble.progress(at: date)
        let popProgress = max(0, (progress - 0.82) / 0.18)
        let growth = 0.18 + progress * 0.82
        let popScale = 1 - popProgress * 0.36
        let scale = growth * popScale
        let opacity = sin(progress * .pi) * (1 - popProgress)

        return Circle()
            .stroke(.white.opacity(0.78), lineWidth: 1.4)
            .background(Circle().fill(.white.opacity(0.10)))
            .frame(width: bubble.diameter, height: bubble.diameter)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(
                x: PetMetrics.bodyInsetX + PetMetrics.bodySize / 2 + bubble.drift * progress,
                y: PetMetrics.canvasHeight - PetMetrics.bodyInsetY - PetMetrics.bodySize / 2 + bubble.startY - bubble.rise * progress
            )
    }
}

private struct SleepBubble: Identifiable {
    let id: Int
    let delay: TimeInterval
    let duration: TimeInterval
    let cycle: TimeInterval
    let diameter: CGFloat
    let drift: CGFloat
    let rise: CGFloat
    var startY: CGFloat {
        2
    }

    func progress(at date: Date) -> CGFloat {
        let time = date.timeIntervalSinceReferenceDate
        let localTime = time.truncatingRemainder(dividingBy: cycle)

        guard localTime >= delay else {
            return 0
        }

        let activeTime = localTime - delay
        guard activeTime <= duration else {
            return 0
        }

        return CGFloat(min(max(activeTime / duration, 0), 1))
    }
}
