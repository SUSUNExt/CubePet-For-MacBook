import SwiftUI

struct MusicNotesView: View {
    let date: Date

    private let notes: [FloatingMusicNote] = [
        FloatingMusicNote(id: 0, symbol: "♪", delay: 1.0, duration: 2.4, cycle: 24, size: 17, drift: -10, rise: 72),
        FloatingMusicNote(id: 1, symbol: "♫", delay: 4.6, duration: 2.7, cycle: 24, size: 19, drift: 14, rise: 88),
        FloatingMusicNote(id: 2, symbol: "♪", delay: 8.3, duration: 2.3, cycle: 24, size: 16, drift: 5, rise: 78),
        FloatingMusicNote(id: 3, symbol: "♫", delay: 12.5, duration: 2.6, cycle: 24, size: 18, drift: -14, rise: 84),
        FloatingMusicNote(id: 4, symbol: "♪", delay: 17.0, duration: 2.5, cycle: 24, size: 17, drift: 12, rise: 76),
        FloatingMusicNote(id: 5, symbol: "♫", delay: 21.1, duration: 2.8, cycle: 24, size: 19, drift: 2, rise: 90)
    ]

    var body: some View {
        ZStack {
            ForEach(notes) { note in
                noteView(note)
            }
        }
        .frame(width: PetMetrics.canvasWidth, height: PetMetrics.canvasHeight)
    }

    private func noteView(_ note: FloatingMusicNote) -> some View {
        let progress = note.progress(at: date)
        let fadeOut = max(0, (progress - 0.72) / 0.28)
        let scale = 0.35 + progress * 0.75
        let opacity = sin(progress * .pi) * (1 - fadeOut * 0.25)

        return Text(note.symbol)
            .font(.system(size: note.size, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.75), radius: 6)
            .scaleEffect(scale)
            .rotationEffect(.degrees(note.drift * 0.35 * progress))
            .opacity(opacity)
            .position(
                x: PetMetrics.bodyInsetX + PetMetrics.bodySize * 0.68 + note.drift * progress,
                y: PetMetrics.canvasHeight - PetMetrics.bodyInsetY - PetMetrics.bodySize * 0.65 - note.rise * progress
            )
    }
}

private struct FloatingMusicNote: Identifiable {
    let id: Int
    let symbol: String
    let delay: TimeInterval
    let duration: TimeInterval
    let cycle: TimeInterval
    let size: CGFloat
    let drift: CGFloat
    let rise: CGFloat

    func progress(at date: Date) -> CGFloat {
        let localTime = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        guard localTime >= delay else { return 0 }

        let activeTime = localTime - delay
        guard activeTime <= duration else { return 0 }

        return CGFloat(min(max(activeTime / duration, 0), 1))
    }
}
