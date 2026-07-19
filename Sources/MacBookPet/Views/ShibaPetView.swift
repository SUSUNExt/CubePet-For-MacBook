import AppKit
import SwiftUI

enum ShibaPetAsset {
    static let normalImage = load(named: "ShibaPet")
    static let happyImage = load(named: "ShibaPetHappy")
    static let scaredImage = load(named: "ShibaPetScaredApproved")
    static let eatingImage = load(named: "ShibaPetEating")
    static let hungryImage = load(named: "ShibaPetHungry")
    static let sleepingImage = load(named: "ShibaPetSleeping")

    static func image(for state: PetVisualState) -> NSImage? {
        switch state {
        case .normal: normalImage
        case .happy: happyImage
        case .scared: scaredImage
        case .eating: eatingImage
        case .hungry: hungryImage
        case .sleeping: sleepingImage
        }
    }

    private static func load(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct ShibaPetImage: View {
    let image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "dog.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.orange)
                .padding(12)
        }
    }
}

struct ShibaPetView: View {
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    let mouthOpen: CGFloat
    let visualConfiguration: PetVisualConfiguration
    var customEyeAsset: PetImportedVisualAsset? = nil
    var appliesVerticalBaseOffsetInView = true

    var body: some View {
        ZStack {
            ShibaPetImage(image: ShibaPetAsset.image(for: visualState))
                .offset(renderedBaseOffset)

            if let eyeConfiguration {
                TrackingEyesView(
                    configuration: eyeConfiguration,
                    expression: expression,
                    isBlinking: isBlinking,
                    gazeOffset: gazeOffset,
                    customEyeAsset: customEyeAsset
                )
                .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
            }
        }
        // The state artwork is intentionally a hard cut.  The click reaction
        // supplies its own feedback, while animating two differently painted
        // illustrations makes their eye layers look like a flash.
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var visualState: PetVisualState {
        mouthOpen > 0.02 ? .eating : PetVisualState(expression: expression)
    }

    private var stateConfiguration: PetStateVisualConfiguration {
        visualConfiguration.configuration(for: visualState)
    }

    private var eyeConfiguration: PetEyeModuleConfiguration? {
        stateConfiguration.eyes
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
}
