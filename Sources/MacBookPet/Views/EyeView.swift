import SwiftUI

struct EyeView: View {
    let style: EyeStyle
    let isBlinking: Bool
    let color: Color

    var body: some View {
        eyeShape
            .foregroundStyle(color)
            .frame(width: size.width, height: size.height)
            .scaleEffect(x: 1, y: isBlinking ? 0.08 : 1, anchor: .center)
            .rotationEffect(rotation)
            .shadow(color: color.opacity(0.80), radius: 8)
            .shadow(color: color.opacity(0.40), radius: 18)
            .animation(.easeInOut(duration: 0.12), value: isBlinking)
    }

    @ViewBuilder
    private var eyeShape: some View {
        switch style {
        case .smile:
            SmileEye(isInverted: false)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        case .invertedSmile:
            SmileEye(isInverted: true)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        case .chevronLeft:
            ChevronEye(opensLeft: true)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        case .chevronRight:
            ChevronEye(opensLeft: false)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        case .sleepy:
            Capsule(style: .continuous)
        case .annoyedLeft, .annoyedRight:
            Capsule(style: .continuous)
        case .round, .largeRound, .smallRound:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
        }
    }

    private var size: CGSize {
        switch style {
        case .round:
            return CGSize(width: 10, height: 15)
        case .largeRound:
            return CGSize(width: 13, height: 17)
        case .smallRound:
            return CGSize(width: 8, height: 13)
        case .smile:
            return CGSize(width: 14, height: 11)
        case .sleepy:
            return CGSize(width: 14, height: 4)
        case .annoyedLeft, .annoyedRight:
            return CGSize(width: 15, height: 4)
        case .chevronLeft, .chevronRight:
            return CGSize(width: 12, height: 16)
        case .invertedSmile:
            return CGSize(width: 14, height: 11)
        }
    }

    private var rotation: Angle {
        switch style {
        case .annoyedLeft:
            return .degrees(14)
        case .annoyedRight:
            return .degrees(-14)
        default:
            return .degrees(0)
        }
    }
}

private struct SmileEye: Shape {
    let isInverted: Bool

    func path(in rect: CGRect) -> Path {
        let controlY = isInverted ? rect.maxY + 4 : rect.minY - 4

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY + 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.midY + 2),
            control: CGPoint(x: rect.midX, y: controlY)
        )
        return path
    }
}

private struct ChevronEye: Shape {
    let opensLeft: Bool

    func path(in rect: CGRect) -> Path {
        let tipX = opensLeft ? rect.minX + 2 : rect.maxX - 2
        let openX = opensLeft ? rect.maxX - 2 : rect.minX + 2

        var path = Path()
        path.move(to: CGPoint(x: openX, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: tipX, y: rect.midY))
        path.addLine(to: CGPoint(x: openX, y: rect.maxY - 2))
        return path
    }
}
