import AppKit

final class PetWindow: NSWindow {
    var physicsController: PetPhysicsController?
    var onRightClick: ((CGRect) -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        title = "MacBook Pet"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if physicsController?.isUsingInputEventTap == true { break }
            physicsController?.beginDrag(with: event)
        case .leftMouseDragged:
            if physicsController?.isUsingInputEventTap == true { break }
            physicsController?.updateDrag(with: event)
            return
        case .leftMouseUp:
            if physicsController?.isUsingInputEventTap == true { break }
            physicsController?.endDrag(with: event)
        case .rightMouseDown:
            guard bodyInteractionBoundsInWindow.contains(event.locationInWindow) else { break }
            onRightClick?(bodyFrameInScreen)
            return
        default:
            break
        }

        super.sendEvent(event)
    }

    private var bodyFrameInScreen: CGRect {
        CGRect(
            x: frame.minX + PetMetrics.bodyInsetX,
            y: frame.minY + PetMetrics.bodyInsetY,
            width: PetMetrics.bodySize,
            height: PetMetrics.bodySize
        )
    }

    private var bodyInteractionBoundsInWindow: CGRect {
        PetMetrics.bodyBoundsInWindow.insetBy(
            dx: -PetMetrics.fileDropMargin,
            dy: -PetMetrics.fileDropMargin
        )
    }
}
