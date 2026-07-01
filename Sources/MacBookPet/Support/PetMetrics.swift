import Foundation

enum PetMetrics {
    static let bodySize: CGFloat = 76
    static let bodyInsetX: CGFloat = 34
    static let bodyInsetY: CGFloat = 34
    static let canvasWidth: CGFloat = 230
    static let canvasHeight: CGFloat = 250
    static let bodyPadding: CGFloat = 5
    static let bodyContentSize: CGFloat = bodySize - bodyPadding * 2
    static let cornerRadius: CGFloat = 11
    static let fileDropMargin: CGFloat = 26

    static var bodyBoundsInWindow: CGRect {
        CGRect(x: bodyInsetX, y: bodyInsetY, width: bodySize, height: bodySize)
    }
}
