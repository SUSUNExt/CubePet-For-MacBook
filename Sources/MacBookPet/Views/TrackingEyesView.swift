import SwiftUI

struct TrackingEyesView: View {
    let configuration: PetEyeModuleConfiguration
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    var additionalOffset: CGSize = .zero

    var body: some View {
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
