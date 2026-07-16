import SwiftUI

struct CubePetView: View {
    let color: Color
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    let mouthOpen: CGFloat
    let visualConfiguration: PetVisualConfiguration
    var customEyeAsset: PetImportedVisualAsset? = nil
    var appliesVerticalBaseOffsetInView = true

    var body: some View {
        ZStack {
            bodyShape
                .offset(renderedBaseOffset)

            if let eyeConfiguration = stateConfiguration.eyes {
                TrackingEyesView(
                    configuration: eatingEyeConfiguration ?? eyeConfiguration,
                    expression: expression,
                    isBlinking: isEating ? false : isBlinking,
                    gazeOffset: isEating ? .zero : gazeOffset,
                    additionalOffset: CGSize(
                        width: 0,
                        height: isEating ? -9 - mouthOpen * 13 : expression.verticalOffset
                    ),
                    customEyeAsset: customEyeAsset
                )
                .animation(.spring(response: 0.18, dampingFraction: 0.72), value: mouthOpen)
            }
        }
    }

    private var visualState: PetVisualState {
        isEating ? .eating : PetVisualState(expression: expression)
    }

    private var stateConfiguration: PetStateVisualConfiguration {
        visualConfiguration.configuration(for: visualState)
    }

    private var isEating: Bool {
        mouthOpen > 0.02
    }

    private var renderedBaseOffset: CGSize {
        let offset = stateConfiguration.baseOffset ?? .zero
        return CGSize(
            width: CGFloat(offset.x) * PetMetrics.bodyContentSize,
            height: appliesVerticalBaseOffsetInView
                ? CGFloat(offset.y) * PetMetrics.bodyContentSize
                : 0
        )
    }

    private var eatingEyeConfiguration: PetEyeModuleConfiguration? {
        guard isEating, var eyes = stateConfiguration.eyes else { return nil }
        eyes.kind = .eating
        return eyes
    }

    @ViewBuilder
    private var bodyShape: some View {
        if mouthOpen > 0.01 {
            let bodySize = PetMetrics.bodyContentSize
            let lowerHeight = bodySize * 0.34
            let upperHeight = bodySize - lowerHeight
            let gap = 3 + mouthOpen * 17

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: PetMetrics.cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(width: bodySize, height: lowerHeight)

                RoundedRectangle(cornerRadius: PetMetrics.cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(width: bodySize, height: upperHeight)
                    .offset(y: -(lowerHeight + gap))
            }
            .frame(width: bodySize, height: bodySize, alignment: .bottom)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: mouthOpen)
        } else {
            RoundedRectangle(cornerRadius: PetMetrics.cornerRadius, style: .continuous)
                .fill(color)
        }
    }
}
