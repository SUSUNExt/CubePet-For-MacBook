import AppKit
import SwiftUI

struct ImportedPetVisualView: View {
    let imageURL: URL?
    let baseOffset: NormalizedVisualOffset?
    let configuration: PetEyeModuleConfiguration?
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize

    var body: some View {
        ZStack {
            Group {
                if let imageURL, let image = NSImage(contentsOf: imageURL) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
            .offset(renderedBaseOffset)

            if let configuration {
                TrackingEyesView(
                    configuration: configuration,
                    expression: expression,
                    isBlinking: isBlinking,
                    gazeOffset: gazeOffset
                )
            }
        }
    }

    private var renderedBaseOffset: CGSize {
        let offset = baseOffset ?? .zero
        return CGSize(
            width: CGFloat(offset.x) * PetMetrics.bodyContentSize,
            height: CGFloat(offset.y) * PetMetrics.bodyContentSize
        )
    }
}
