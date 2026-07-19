import SwiftUI

struct SleepZzzView: View {
    let date: Date

    private let symbols: [SleepZzzSymbol] = [
        SleepZzzSymbol(id: 0, delay: 0, size: 12, x: 88, y: 152),
        SleepZzzSymbol(id: 1, delay: 0.7, size: 15.5, x: 101, y: 139),
        SleepZzzSymbol(id: 2, delay: 1.4, size: 19.5, x: 116, y: 124)
    ]

    var body: some View {
        ZStack {
            ForEach(symbols) { symbol in
                symbolView(symbol)
            }
        }
        .frame(width: PetMetrics.canvasWidth, height: PetMetrics.canvasHeight)
    }

    private func symbolView(_ symbol: SleepZzzSymbol) -> some View {
        let progress = symbol.progress(at: date)

        return Text("z")
            .font(.system(size: symbol.size, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.78))
            .scaleEffect(0.16 + 0.84 * progress.appearProgress)
            .opacity(progress.opacity)
            .position(x: symbol.x, y: symbol.y)
    }
}

private struct SleepZzzSymbol: Identifiable {
    private static let cycle: TimeInterval = 4.1
    private static let appearanceDuration: TimeInterval = 0.42
    private static let disappearanceStart: TimeInterval = 3.25
    private static let disappearanceDuration: TimeInterval = 0.42

    let id: Int
    let delay: TimeInterval
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat

    func progress(at date: Date) -> (appearProgress: CGFloat, opacity: CGFloat) {
        let time = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Self.cycle)
        let appearance = min(max((time - delay) / Self.appearanceDuration, 0), 1)
        let easedAppearance = CGFloat(1 - pow(1 - appearance, 3))
        let disappearance = min(
            max((time - Self.disappearanceStart) / Self.disappearanceDuration, 0),
            1
        )

        return (easedAppearance, easedAppearance * CGFloat(1 - disappearance))
    }
}
