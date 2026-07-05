import AppKit
import SwiftUI

enum FrogPetAsset {
    static let image = load(named: "FrogPet")
    static let largeMouthImage = load(named: "FrogPetMouthLarge")

    private static func load(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct FrogPetImage: View {
    let image: NSImage?

    init(image: NSImage? = FrogPetAsset.image) {
        self.image = image
    }

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Ellipse()
                .fill(Color(red: 0.39, green: 0.48, blue: 0.16))
                .padding(7)
        }
    }
}

struct FrogPetView: View {
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    let mouthOpen: CGFloat
    let visualConfiguration: PetVisualConfiguration

    var body: some View {
        let isEating = mouthOpen > 0.02

        return ZStack {
            ZStack {
                FrogPetImage()

                if isEating {
                    FrogPetImage(image: FrogPetAsset.largeMouthImage)
                        .mask(
                            Ellipse()
                                .fill(
                                    RadialGradient(
                                        colors: [.white, .white, .clear],
                                        center: .center,
                                        startRadius: 7,
                                        endRadius: 11
                                    )
                                )
                                .frame(width: 22, height: 20)
                                .offset(x: 0.8, y: 0.5)
                        )
                }
            }
            .offset(renderedBaseOffset)

            if let eyeConfiguration {
                FrogEyePairView(
                    configuration: eyeConfiguration,
                    expression: expression,
                    isBlinking: isEating ? false : isBlinking,
                    gazeOffset: isEating ? .zero : gazeOffset
                )
            }
        }
        .scaleEffect(x: 1, y: isEating ? 1.10 : 1, anchor: .bottom)
        .animation(.spring(response: 0.28, dampingFraction: 0.52), value: isEating)
    }

    private var stateConfiguration: PetStateVisualConfiguration {
        visualConfiguration.configuration(
            for: mouthOpen > 0.02 ? .eating : PetVisualState(expression: expression)
        )
    }

    private var eyeConfiguration: PetEyeModuleConfiguration? {
        guard var eyes = stateConfiguration.eyes else { return nil }
        if mouthOpen > 0.02 {
            eyes.kind = .eating
        }
        return eyes
    }

    private var renderedBaseOffset: CGSize {
        let offset = stateConfiguration.baseOffset ?? .zero
        return CGSize(
            width: CGFloat(offset.x) * PetMetrics.bodyContentSize,
            height: CGFloat(offset.y) * PetMetrics.bodyContentSize
        )
    }
}

private struct FrogEyePairView: View {
    let configuration: PetEyeModuleConfiguration
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize

    var body: some View {
        EyePairLayout(configuration: configuration) {
            frogEye(style: eyeStyles.left)
        } rightEye: {
            frogEye(style: eyeStyles.right)
        }
    }

    private var eyeStyles: (left: EyeStyle, right: EyeStyle) {
        configuration.eyeStyles(for: expression)
    }

    private var effectiveBlinking: Bool {
        configuration.allowsBlinking && isBlinking
    }

    private var effectiveGaze: CGSize {
        guard configuration.followsMouse(for: expression) else { return .zero }
        return CGSize(width: gazeOffset.width * 0.42, height: gazeOffset.height * 0.42)
    }

    private func frogEye(style: EyeStyle) -> some View {
        FrogEyeMark(
            style: style,
            isBlinking: effectiveBlinking,
            ink: eyeInk
        )
            .scaleEffect(CGFloat(configuration.resolvedPupilScale))
            .offset(effectiveGaze)
            .animation(.easeOut(duration: 0.10), value: gazeOffset)
    }

    private var eyeInk: Color {
        switch configuration.resolvedColorMode {
        case .automatic:
            Color(red: 0.10, green: 0.075, blue: 0.045)
        case .black:
            .black
        case .white:
            .white
        }
    }
}

private struct FrogEyeMark: View {
    let style: EyeStyle
    let isBlinking: Bool
    let ink: Color

    var body: some View {
        Group {
            if isBlinking {
                Capsule(style: .continuous)
                    .fill(ink)
                    .frame(width: 8, height: 2)
            } else {
                eyeShape
            }
        }
        .frame(width: 13, height: 13)
    }

    @ViewBuilder
    private var eyeShape: some View {
        switch style {
        case .round:
            Circle().fill(ink).frame(width: 3.6, height: 3.6)
        case .largeRound:
            Circle().fill(ink).frame(width: 4.8, height: 4.8)
        case .smallRound:
            Circle().fill(ink).frame(width: 2.8, height: 2.8)
        case .smile:
            FrogArcEye(isInverted: false)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 8, height: 6)
        case .invertedSmile:
            FrogArcEye(isInverted: true)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 8, height: 6)
        case .sleepy:
            Capsule(style: .continuous).fill(ink).frame(width: 8, height: 2)
        case .annoyedLeft:
            Capsule(style: .continuous).fill(ink).frame(width: 9, height: 2).rotationEffect(.degrees(14))
        case .annoyedRight:
            Capsule(style: .continuous).fill(ink).frame(width: 9, height: 2).rotationEffect(.degrees(-14))
        case .chevronLeft:
            FrogChevronEye(opensLeft: true)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 9)
        case .chevronRight:
            FrogChevronEye(opensLeft: false)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 9)
        }
    }

}

private struct FrogArcEye: Shape {
    let isInverted: Bool

    func path(in rect: CGRect) -> Path {
        let controlY = isInverted ? rect.maxY + 2 : rect.minY - 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 1, y: rect.midY),
            control: CGPoint(x: rect.midX, y: controlY)
        )
        return path
    }
}

private struct FrogChevronEye: Shape {
    let opensLeft: Bool

    func path(in rect: CGRect) -> Path {
        let tipX = opensLeft ? rect.minX + 1 : rect.maxX - 1
        let openX = opensLeft ? rect.maxX - 1 : rect.minX + 1
        var path = Path()
        path.move(to: CGPoint(x: openX, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: tipX, y: rect.midY))
        path.addLine(to: CGPoint(x: openX, y: rect.maxY - 1))
        return path
    }
}
