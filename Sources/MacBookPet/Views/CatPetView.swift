import AppKit
import SwiftUI

enum CatPetAsset {
    static let image = load(named: "CatPet")
    static let largeMouthImage = load(named: "CatPetMouthLarge")
    static let grayTabbyImage = load(named: "CatPetGrayFaceless")
    static let grayTabbyLargeMouthImage = load(named: "CatPetGrayMouthLarge")
    static let calicoImage = load(named: "CatPetCalicoFaceless")
    static let calicoLargeMouthImage = load(named: "CatPetCalicoMouthLarge")

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

    var body: some View {
        TimelineView(.animation) { timeline in
            let isEating = mouthOpen > 0.02
            let eyeShiftX: CGFloat = isCalico ? -3.8 : (isGrayTabby ? -1.3 : 0)
            let eyeOffsetY: CGFloat = isCalico ? -14.0 : (isGrayTabby ? -17.2 : -12.0)

            ZStack {
                CatPetImage(image: catImage(isEating: isEating))
                    .scaleEffect(isGrayTabby ? 1.18 : 1, anchor: .bottom)

                ZStack {
                    if isEating || showsEyeWhites {
                        Circle()
                            .fill(.white)
                            .frame(width: 9.2, height: 9.2)
                            .offset(x: -6.1 + eyeShiftX, y: eyeOffsetY)

                        Circle()
                            .fill(.white)
                            .frame(width: 9.2, height: 9.2)
                            .offset(x: 5.1 + eyeShiftX, y: eyeOffsetY)
                    }

                    catEye(
                        style: isEating ? .round : expression.leftEye,
                        isBlinking: isEating ? false : isBlinking,
                        date: timeline.date,
                        isEating: isEating
                    )
                    .offset(x: -6.1 + eyeShiftX, y: eyeOffsetY)

                    catEye(
                        style: isEating ? .round : expression.rightEye,
                        isBlinking: isEating ? false : isBlinking,
                        date: timeline.date,
                        isEating: isEating
                    )
                    .offset(x: 5.1 + eyeShiftX, y: eyeOffsetY)
                }
                .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
                .scaleEffect(isGrayTabby ? 1.08 : 1, anchor: .bottom)
            }
            .offset(y: isGrayTabby ? 2 : 0)
            .scaleEffect(x: 1, y: isEating ? 1.06 : 1, anchor: .bottom)
            .animation(.spring(response: 0.26, dampingFraction: 0.58), value: isEating)
        }
    }

    private var isGrayTabby: Bool {
        skinID == "cat.grayTabby"
    }

    private var isCalico: Bool {
        skinID == "cat.calico"
    }

    private func catImage(isEating: Bool) -> NSImage? {
        if isEating {
            if isGrayTabby { return CatPetAsset.grayTabbyLargeMouthImage }
            if isCalico { return CatPetAsset.calicoLargeMouthImage }
            return CatPetAsset.largeMouthImage
        }
        if isGrayTabby { return CatPetAsset.grayTabbyImage }
        if isCalico { return CatPetAsset.calicoImage }
        return CatPetAsset.image
    }

    private var showsEyeWhites: Bool {
        switch expression {
        case .calm, .curious, .drowsy:
            return true
        default:
            return false
        }
    }

    private func catEye(style: EyeStyle, isBlinking: Bool, date: Date, isEating: Bool) -> some View {
        CatEyeMark(style: style, isBlinking: isBlinking, date: date)
            .offset(
                x: isEating ? 0 : (expression.allowsMouseGaze ? gazeOffset.width * 0.44 : 0),
                y: isEating ? 0.9 : (expression.allowsMouseGaze ? gazeOffset.height * 0.44 : 0)
            )
            .animation(.easeOut(duration: 0.10), value: gazeOffset)
            .animation(.spring(response: 0.18, dampingFraction: 0.70), value: isEating)
    }
}

private struct CatEyeMark: View {
    let style: EyeStyle
    let isBlinking: Bool
    let date: Date

    private let ink = Color(red: 0.08, green: 0.055, blue: 0.035)

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
        case .drowsy:
            Circle()
                .fill(ink)
                .frame(width: 5.6, height: 5.6)
                .scaleEffect(x: 1, y: drowsyScale, anchor: .center)
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

    private var drowsyScale: CGFloat {
        let wave = (sin(date.timeIntervalSinceReferenceDate * 1.8) + 1) / 2
        return 0.35 + CGFloat(wave) * 0.65
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
