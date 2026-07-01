import AppKit

final class PetWindow: NSWindow {
    var physicsController: PetPhysicsController?

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
        default:
            break
        }

        super.sendEvent(event)
    }
}
