import AppKit
import SwiftUI

struct TrackingEyesView: View {
    let configuration: PetEyeModuleConfiguration
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    var additionalOffset: CGSize = .zero
    var customEyeAsset: PetImportedVisualAsset? = nil

    var body: some View {
        Group {
            if let customEyeAsset {
                CustomEyePairView(
                    asset: customEyeAsset,
                    configuration: configuration,
                    additionalOffset: additionalOffset
                )
            } else if configuration.kind == .catDefault {
                DefaultCatEyePairView(
                    configuration: configuration,
                    isBlinking: effectiveBlinking,
                    gazeOffset: effectiveGaze,
                    additionalOffset: additionalOffset
                )
            } else {
                EyePairLayout(
                    configuration: configuration,
                    additionalOffset: CGSize(
                        width: effectiveGaze.width + additionalOffset.width,
                        height: effectiveGaze.height + additionalOffset.height
                    )
                ) {
                    EyeView(
                        style: eyeStyles.left,
                        isBlinking: effectiveBlinking,
                        color: eyeColor
                    )
                    .scaleEffect(eyeLayerScale)
                } rightEye: {
                    EyeView(
                        style: eyeStyles.right,
                        isBlinking: effectiveBlinking,
                        color: eyeColor
                    )
                    .scaleEffect(eyeLayerScale)
                }
            }
        }
        .animation(.easeOut(duration: 0.10), value: gazeOffset)
    }

    private var eyeStyles: (left: EyeStyle, right: EyeStyle) {
        configuration.eyeStyles(for: expression)
    }

    private var effectiveBlinking: Bool {
        configuration.allowsBlinking && isBlinking
    }

    private var effectiveGaze: CGSize {
        configuration.followsMouse(for: expression) ? gazeOffset : .zero
    }

    private var eyeColor: Color {
        switch configuration.resolvedColorMode {
        case .automatic, .white: .white
        case .black: .black
        }
    }

    private var eyeLayerScale: CGFloat {
        switch configuration.resolvedColorMode {
        case .black:
            CGFloat(configuration.resolvedPupilScale)
        case .automatic, .white:
            CGFloat(configuration.resolvedOuterEyeScale)
        }
    }
}

/// The cat's standard wide eyes, available to imported custom pets as a reusable module.
private struct DefaultCatEyePairView: View {
    let configuration: PetEyeModuleConfiguration
    let isBlinking: Bool
    let gazeOffset: CGSize
    let additionalOffset: CGSize

    var body: some View {
        EyePairLayout(configuration: configuration, additionalOffset: additionalOffset) {
            catEye
        } rightEye: {
            catEye
        }
    }

    private var catEye: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 9.2, height: 9.2)
                .scaleEffect(CGFloat(configuration.resolvedOuterEyeScale))

            if isBlinking {
                Capsule(style: .continuous)
                    .fill(.black)
                    .frame(width: 9, height: 2)
            } else {
                Circle()
                    .fill(.black)
                    .frame(width: 5.6, height: 5.6)
                    .scaleEffect(CGFloat(configuration.resolvedPupilScale))
                    .offset(gazeOffset)
                    .animation(.easeOut(duration: 0.10), value: gazeOffset)
            }
        }
        .frame(width: 14, height: 14)
    }
}

struct CustomEyePairView: View {
    let asset: PetImportedVisualAsset
    let configuration: PetEyeModuleConfiguration
    var additionalOffset: CGSize = .zero

    var body: some View {
        EyePairLayout(configuration: configuration, additionalOffset: additionalOffset) {
            eyeImage
        } rightEye: {
            eyeImage
        }
    }

    private var eyeImage: some View {
        Group {
            if let image = NSImage(contentsOf: asset.imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
        .scaleEffect(CGFloat(configuration.resolvedPupilScale))
    }
}

struct EyePairLayout<LeftEye: View, RightEye: View>: View {
    let configuration: PetEyeModuleConfiguration
    let additionalOffset: CGSize
    let leftEye: LeftEye
    let rightEye: RightEye

    init(
        configuration: PetEyeModuleConfiguration,
        additionalOffset: CGSize = .zero,
        @ViewBuilder leftEye: () -> LeftEye,
        @ViewBuilder rightEye: () -> RightEye
    ) {
        self.configuration = configuration
        self.additionalOffset = additionalOffset
        self.leftEye = leftEye()
        self.rightEye = rightEye()
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                leftEye
                    .offset(eyeOffset(configuration.leftEyeOffset, in: geometry.size))
                rightEye
                    .offset(
                        eyeOffset(configuration.rightEyeOffset, in: geometry.size)
                            + CGSize(width: 0, height: rightEyeOffsetY)
                    )
            }
            .scaleEffect(scale)
            .position(
                x: clampedCenterX * geometry.size.width + additionalOffset.width,
                y: clampedCenterY * geometry.size.height + additionalOffset.height
            )
        }
    }

    private var clampedCenterX: CGFloat {
        CGFloat(min(max(configuration.center.x, 0), 1))
    }

    private var clampedCenterY: CGFloat {
        CGFloat(min(max(configuration.center.y, 0), 1))
    }

    private var scale: CGFloat {
        CGFloat(min(max(configuration.scale, 0.25), 4))
    }

    private var spacing: CGFloat {
        CGFloat(min(max(configuration.spacing, -20), 80))
    }

    private var rightEyeOffsetY: CGFloat {
        CGFloat(min(max(configuration.rightEyeOffsetY ?? 0, -40), 40))
    }

    private func eyeOffset(
        _ normalizedOffset: NormalizedVisualOffset?,
        in size: CGSize
    ) -> CGSize {
        guard let normalizedOffset else { return .zero }
        return CGSize(
            width: CGFloat(normalizedOffset.x) * size.width / scale,
            height: CGFloat(normalizedOffset.y) * size.height / scale
        )
    }
}

private func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}
