import AppKit
import SwiftUI

enum CatPetAsset {
    static let image = load(named: "CatPet")
    static let largeMouthImage = load(named: "CatPetMouthLarge")
    static let grayTabbyImage = load(named: "CatPetGrayFaceless")
    static let grayTabbyLargeMouthImage = load(named: "CatPetGrayMouthLarge")
    static let calicoImage = load(named: "CatPetCalicoFaceless")
    static let calicoLargeMouthImage = load(named: "CatPetCalicoMouthLarge")
    static let blackImage = load(named: "CatPetBlackFaceless")
    static let blackLargeMouthImage = load(named: "CatPetBlackMouthLarge")
    static let siameseImage = load(named: "CatPetSiameseFaceless")
    static let siameseMouthImage = load(named: "CatPetSiameseMouthUnique")

    private static func load(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct CatPetImage: View {
    let image: NSImage?

    init(image: NSImage? = CatPetAsset.image) {
        self.image = image
    }

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Circle()
                .fill(Color(red: 0.94, green: 0.44, blue: 0.08))
                .overlay(
                    VStack(spacing: 2) {
                        HStack(spacing: 7) {
                            Circle().fill(.white).frame(width: 9, height: 9)
                            Circle().fill(.white).frame(width: 9, height: 9)
                        }
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.05, green: 0.16, blue: 0.24))
                            .frame(width: 36, height: 5)
                    }
                    .offset(y: -5)
                )
                .padding(6)
        }
    }
}

struct CatPetView: View {
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    let mouthOpen: CGFloat
    let skinID: String
    let visualConfiguration: PetVisualConfiguration

    var body: some View {
        let isEating = mouthOpen > 0.02
        let defaultEyeScale: CGFloat = !isEating && expression == .calm ? 0.86 : 1
        let defaultEyeOffsetY: CGFloat = !isEating && expression == .calm ? 1.2 : 0
        let eyeBackgroundScale: CGFloat = isBlack ? 0.9 : 1
        let eyeMarkScale: CGFloat = isSiamese && (isEating || !usesWhiteEyeInk)
            ? 0.70
            : eyeBackgroundScale

        return ZStack {
            ZStack {
                CatPetImage(image: catImage(isEating: false))
                    .scaleEffect(isGrayTabby ? 1.18 : 1, anchor: .bottom)

                if isEating {
                    CatPetImage(image: catImage(isEating: true))
                        .scaleEffect(
                            isGrayTabby ? 1.18 : (isDefaultSkin ? 0.925 : 1),
                            anchor: .bottom
                        )
                        .offset(
                            x: isDefaultSkin ? 1.6 : 0,
                            y: isDefaultSkin ? -3.2 : 0
                        )
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .offset(renderedBaseOffset)

            if let eyeConfiguration, !(isEating && usesBakedEatingEyes) {
                CatEyePairView(
                    configuration: eyeConfiguration,
                    expression: expression,
                    isBlinking: isEating ? false : isBlinking,
                    gazeOffset: isEating ? .zero : gazeOffset,
                    additionalOffsetY: defaultEyeOffsetY,
                    showsEyeWhites: isEating || showsEyeWhites,
                    eyeBackgroundScale: eyeBackgroundScale
                        * defaultEyeScale
                        * CGFloat(eyeConfiguration.resolvedOuterEyeScale),
                    eyeMarkScale: eyeMarkScale
                        * defaultEyeScale
                        * CGFloat(eyeConfiguration.resolvedPupilScale),
                    eyeInk: resolvedEyeInk(isEating: isEating)
                )
                .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
                .scaleEffect(isGrayTabby ? 1.08 : 1, anchor: .bottom)
            }
        }
        .offset(y: isGrayTabby ? 2 : 0)
        .scaleEffect(
            x: 1,
            y: isEating && !isDefaultSkin && !isGrayTabby ? 1.06 : 1,
            anchor: .bottom
        )
    }

    private var isGrayTabby: Bool {
        skinID == "cat.grayTabby"
    }

    private var isCalico: Bool {
        skinID == "cat.calico"
    }

    private var isBlack: Bool {
        skinID == "cat.black"
    }

    private var isSiamese: Bool {
        skinID == "cat.siamese"
    }

    private var usesBakedEatingEyes: Bool {
        return isGrayTabby || isCalico || isBlack || isSiamese || isDefaultSkin
    }

    private var isDefaultSkin: Bool {
        !isGrayTabby && !isCalico && !isBlack && !isSiamese
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

    private func catImage(isEating: Bool) -> NSImage? {
        if isEating {
            if isGrayTabby { return CatPetAsset.grayTabbyLargeMouthImage }
            if isCalico { return CatPetAsset.calicoLargeMouthImage }
            if isBlack { return CatPetAsset.blackLargeMouthImage }
            if isSiamese { return CatPetAsset.siameseMouthImage }
            return CatPetAsset.largeMouthImage
        }
        if isGrayTabby { return CatPetAsset.grayTabbyImage }
        if isCalico { return CatPetAsset.calicoImage }
        if isBlack { return CatPetAsset.blackImage }
        if isSiamese { return CatPetAsset.siameseImage }
        return CatPetAsset.image
    }

    private var showsEyeWhites: Bool {
        switch expression {
        case .calm, .curious:
            return true
        default:
            return false
        }
    }

    private var automaticEyeInk: Color {
        guard isBlack || isSiamese else {
            return Color(red: 0.08, green: 0.055, blue: 0.035)
        }

        switch expression {
        case .happy, .scared, .sleeping:
            return .white
        default:
            return Color(red: 0.08, green: 0.055, blue: 0.035)
        }
    }

    private func resolvedEyeInk(isEating: Bool) -> Color {
        switch stateConfiguration.eyes?.resolvedColorMode ?? .automatic {
        case .black:
            return .black
        case .white:
            return .white
        case .automatic:
            return isEating
                ? Color(red: 0.08, green: 0.055, blue: 0.035)
                : automaticEyeInk
        }
    }

    private var usesWhiteEyeInk: Bool {
        switch stateConfiguration.eyes?.resolvedColorMode ?? .automatic {
        case .black:
            return false
        case .white:
            return true
        case .automatic:
            break
        }

        guard isBlack || isSiamese else { return false }

        switch expression {
        case .happy, .scared, .sleeping:
            return true
        default:
            return false
        }
    }
}

private struct CatEyePairView: View {
    let configuration: PetEyeModuleConfiguration
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    let additionalOffsetY: CGFloat
    let showsEyeWhites: Bool
    let eyeBackgroundScale: CGFloat
    let eyeMarkScale: CGFloat
    let eyeInk: Color

    var body: some View {
        EyePairLayout(
            configuration: configuration,
            additionalOffset: CGSize(width: 0, height: additionalOffsetY)
        ) {
            catEye(style: eyeStyles.left)
        } rightEye: {
            catEye(style: eyeStyles.right)
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
        return CGSize(width: gazeOffset.width * 0.44, height: gazeOffset.height * 0.44)
    }

    private func catEye(style: EyeStyle) -> some View {
        ZStack {
            if showsEyeWhites {
                Circle()
                    .fill(.white)
                    .frame(width: 9.2, height: 9.2)
                    .scaleEffect(eyeBackgroundScale)
            }

            CatEyeMark(
                style: style,
                isBlinking: effectiveBlinking,
                ink: eyeInk
            )
            .scaleEffect(eyeMarkScale)
            .offset(effectiveGaze)
            .animation(.easeOut(duration: 0.10), value: gazeOffset)
        }
        .frame(width: 14, height: 14)
    }
}

private struct CatEyeMark: View {
    let style: EyeStyle
    let isBlinking: Bool
    let ink: Color

    var body: some View {
        Group {
            if isBlinking {
                Capsule(style: .continuous)
                    .fill(ink)
                    .frame(width: 9, height: 2)
            } else {
                eyeShape
            }
        }
        .frame(width: 14, height: 14)
    }

    @ViewBuilder
    private var eyeShape: some View {
        switch style {
        case .round:
            Circle().fill(ink).frame(width: 5.6, height: 5.6)
        case .largeRound:
            Circle().fill(ink).frame(width: 6.8, height: 6.8)
        case .smallRound:
            Circle().fill(ink).frame(width: 4.1, height: 4.1)
        case .smile:
            CatArcEye(isInverted: false)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 8, height: 6)
        case .invertedSmile:
            CatArcEye(isInverted: true)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 8, height: 6)
        case .sleepy:
            Capsule(style: .continuous).fill(ink).frame(width: 9, height: 2)
        case .annoyedLeft:
            Capsule(style: .continuous).fill(ink).frame(width: 9, height: 2).rotationEffect(.degrees(14))
        case .annoyedRight:
            Capsule(style: .continuous).fill(ink).frame(width: 9, height: 2).rotationEffect(.degrees(-14))
        case .chevronLeft:
            CatChevronEye(opensLeft: true)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 9)
        case .chevronRight:
            CatChevronEye(opensLeft: false)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 9)
        }
    }

}

private struct CatArcEye: Shape {
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

private struct CatChevronEye: Shape {
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
