import AppKit
import SwiftUI

final class PetHostingView<Content: View>: NSHostingView<Content> {
    var motionState: PetMotionState?
    var onFeedInteractionBegan: (() -> Void)?
    var canAcceptFeedFiles: (([URL]) -> Bool)?
    var onFeedFiles: (([URL]) -> Bool)?
    private var isFeedInteractionActive = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateFeedingMouth(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateFeedingMouth(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        endFeedInteraction()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        endFeedInteraction()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let location = sender.draggingLocation
        let dropBounds = PetMetrics.bodyBoundsInWindow.insetBy(
            dx: -PetMetrics.fileDropMargin,
            dy: -PetMetrics.fileDropMargin
        )
        let fileURLs = fileURLs(from: sender.draggingPasteboard)

        guard
            dropBounds.contains(location),
            !fileURLs.isEmpty,
            canAcceptFeedFiles?(fileURLs) != false,
            onFeedFiles?(fileURLs) == true
        else {
            endFeedInteraction()
            return false
        }

        playEatingAnimation()
        return true
    }

    private func updateFeedingMouth(for sender: NSDraggingInfo) -> NSDragOperation {
        let fileURLs = fileURLs(from: sender.draggingPasteboard)
        guard !fileURLs.isEmpty, canAcceptFeedFiles?(fileURLs) != false else {
            endFeedInteraction()
            return []
        }

        let location = sender.draggingLocation
        let feedRange = PetMetrics.bodyBoundsInWindow.insetBy(dx: -95, dy: -95)

        guard feedRange.contains(location) else {
            endFeedInteraction()
            return []
        }

        if !isFeedInteractionActive {
            isFeedInteractionActive = true
            onFeedInteractionBegan?()
        }

        let center = CGPoint(x: PetMetrics.bodyBoundsInWindow.midX, y: PetMetrics.bodyBoundsInWindow.midY)
        let distance = hypot(location.x - center.x, location.y - center.y)
        let maxDistance = CGFloat(145)
        let closeness = 1 - min(distance / maxDistance, 1)
        motionState?.feedMouthOpen = max(0.18, closeness)

        return .move
    }

    private func endFeedInteraction() {
        motionState?.feedMouthOpen = 0
        isFeedInteractionActive = false
    }

    private func playEatingAnimation() {
        motionState?.gazeOffset = .zero
        motionState?.feedMouthOpen = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.motionState?.feedMouthOpen = 0.38
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
            self?.motionState?.feedMouthOpen = 0
        }
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []

        return objects.compactMap { object in
            if let url = object as? URL {
                return url
            }

            if let url = object as? NSURL {
                return url as URL
            }

            return nil
        }
    }
}
