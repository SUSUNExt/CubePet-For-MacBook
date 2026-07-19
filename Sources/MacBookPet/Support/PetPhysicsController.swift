import AppKit

@MainActor
final class PetPhysicsController {
    private static let dragActivationDistance: CGFloat = 5

    private weak var window: NSWindow?
    private let motionState: PetMotionState

    private var timer: Timer?
    private var inputEventTap: CFMachPort?
    private var inputEventRunLoopSource: CFRunLoopSource?
    private var localRightClickMonitor: Any?
    private var globalRightClickMonitor: Any?
    private var lastStepTime = ProcessInfo.processInfo.systemUptime
    private var lastGazeUpdateTime = ProcessInfo.processInfo.systemUptime

    private var position: CGPoint
    private var velocity = CGVector(dx: 0, dy: 0)

    private var dragAnchorInWindow: CGPoint?
    private var dragTargetOrigin: CGPoint?
    private var dragStartMouse: CGPoint?
    private var lastDragMouse: CGPoint?
    private var lastDragTime: TimeInterval?
    private var dragMouseVelocity = CGVector(dx: 0, dy: 0)
    private var flingVelocity = CGVector(dx: 0, dy: 0)
    private var flingVelocityTime: TimeInterval?
    private var maxDragDistance: CGFloat = 0
    private var hasTriggeredGrabReaction = false
    private var isTrackingInputTapDrag = false

    var onClick: (() -> Void)?
    var onRightClick: ((CGRect) -> Void)?
    var onGrab: (() -> Void)?
    var onLand: (() -> Void)?
    var isMouseGazeEnabled: (() -> Bool)?
    var isBottomPetEnabled: (() -> Bool)?
    var isUsingInputEventTap: Bool {
        inputEventTap != nil
    }

    init(window: NSWindow, motionState: PetMotionState) {
        self.window = window
        self.motionState = motionState
        self.position = window.frame.origin
    }

    func start() {
        timer?.invalidate()
        lastStepTime = ProcessInfo.processInfo.systemUptime

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            // The timer is explicitly attached to RunLoop.main below, so stepping
            // synchronously avoids allocating a new task for every physics frame.
            MainActor.assumeIsolated {
                self?.step()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        startInputEventTap()
        startRightClickEventMonitors()
    }

    func beginDrag(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        beginDrag(mouse: mouse, anchorInWindow: event.locationInWindow, timestamp: event.timestamp)
    }

    func updateDrag(with event: NSEvent) {
        updateDrag(mouse: NSEvent.mouseLocation, timestamp: event.timestamp)
    }

    func endDrag(with event: NSEvent) {
        endDrag(timestamp: event.timestamp)
    }

    func handleInputEventTap(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let inputEventTap {
                CGEvent.tapEnable(tap: inputEventTap, enable: true)
            }
            return
        }

        let mouse = appKitMouseLocation(from: event)
        let timestamp = TimeInterval(event.timestamp) / 1_000_000_000

        switch type {
        case .leftMouseDown:
            guard let window, bodyFrame(for: window).contains(mouse) else { return }

            isTrackingInputTapDrag = true
            let anchor = CGPoint(x: mouse.x - window.frame.minX, y: mouse.y - window.frame.minY)
            beginDrag(mouse: mouse, anchorInWindow: anchor, timestamp: timestamp)
        case .leftMouseDragged:
            guard isTrackingInputTapDrag else { return }
            updateDrag(mouse: mouse, timestamp: timestamp)
        case .leftMouseUp:
            guard isTrackingInputTapDrag else { return }
            isTrackingInputTapDrag = false
            endDrag(timestamp: timestamp)
        default:
            break
        }
    }

    private func beginDrag(mouse: CGPoint, anchorInWindow: CGPoint, timestamp: TimeInterval) {
        let locationInWindow = anchorInWindow
        guard bodyBoundsInWindow.contains(locationInWindow) else { return }

        dragAnchorInWindow = locationInWindow
        dragTargetOrigin = CGPoint(x: mouse.x - locationInWindow.x, y: mouse.y - locationInWindow.y)
        dragStartMouse = mouse
        lastDragMouse = mouse
        lastDragTime = timestamp
        dragMouseVelocity = CGVector(dx: 0, dy: 0)
        flingVelocity = CGVector(dx: 0, dy: 0)
        flingVelocityTime = nil
        maxDragDistance = 0
        hasTriggeredGrabReaction = false

        motionState.isGrabbed = true
        setGazeOffset(.zero)
    }

    private func updateDrag(mouse: CGPoint, timestamp: TimeInterval) {
        guard let dragAnchorInWindow else { return }

        dragTargetOrigin = CGPoint(x: mouse.x - dragAnchorInWindow.x, y: mouse.y - dragAnchorInWindow.y)

        let now = timestamp
        if let lastDragMouse, let lastDragTime {
            let dt = CGFloat(now - lastDragTime)
            if dt > 0.001 {
                let instantVelocity = CGVector(
                    dx: (mouse.x - lastDragMouse.x) / dt,
                    dy: (mouse.y - lastDragMouse.y) / dt
                )
                dragMouseVelocity.dx = dragMouseVelocity.dx * 0.28 + instantVelocity.dx * 0.72
                dragMouseVelocity.dy = dragMouseVelocity.dy * 0.28 + instantVelocity.dy * 0.72
                recordFlingVelocity(instantVelocity, at: now)
            }
        }
        lastDragMouse = mouse
        lastDragTime = now

        if let dragStartMouse {
            maxDragDistance = Swift.max(maxDragDistance, mouse.distance(to: dragStartMouse))
        }

        if !hasTriggeredGrabReaction, maxDragDistance >= Self.dragActivationDistance {
            hasTriggeredGrabReaction = true
            onGrab?()
        }
    }

    private func endDrag(timestamp: TimeInterval) {
        let wasClick = maxDragDistance < Self.dragActivationDistance
        let releaseVelocity = releaseVelocity(at: timestamp)
        dragAnchorInWindow = nil
        dragTargetOrigin = nil
        dragStartMouse = nil
        lastDragMouse = nil
        lastDragTime = nil
        dragMouseVelocity = CGVector(dx: 0, dy: 0)
        flingVelocity = CGVector(dx: 0, dy: 0)
        flingVelocityTime = nil
        maxDragDistance = 0
        hasTriggeredGrabReaction = false

        motionState.isGrabbed = false

        if wasClick {
            velocity.dx *= 0.25
            velocity.dy *= 0.25
            onClick?()
        } else if isBottomPetEnabled?() == true {
            velocity = CGVector(dx: 0, dy: 0)
        } else {
            velocity.dx = releaseVelocity.dx * 1.08
            velocity.dy = releaseVelocity.dy * 1.08
        }
    }

    private func startInputEventTap() {
        guard inputEventTap == nil else { return }

        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }

        let mask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: petInputEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        inputEventTap = tap
        inputEventRunLoopSource = source
    }

    private func startRightClickEventMonitors() {
        guard localRightClickMonitor == nil, globalRightClickMonitor == nil else { return }

        localRightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.handleRightClickEvent(event)
            }
            return event
        }
        globalRightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.handleRightClickEvent(event)
            }
        }
    }

    private func handleRightClickEvent(_ event: NSEvent) {
        guard let window else { return }
        let mouse = screenPoint(for: event)
        guard bodyInteractionFrame(for: window).contains(mouse) else { return }
        onRightClick?(bodyFrame(for: window))
    }

    private func screenPoint(for event: NSEvent) -> CGPoint {
        if let eventWindow = event.window {
            return eventWindow.convertPoint(toScreen: event.locationInWindow)
        }

        return NSEvent.mouseLocation
    }

    private func appKitMouseLocation(from event: CGEvent) -> CGPoint {
        let quartzPoint = event.location
        let maxScreenY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        return CGPoint(x: quartzPoint.x, y: maxScreenY - quartzPoint.y)
    }

    private func recordFlingVelocity(_ candidate: CGVector, at time: TimeInterval) {
        let candidateSpeed = candidate.speed
        let currentSpeed = flingVelocity.speed

        if candidateSpeed > currentSpeed * 0.72 || flingVelocityTime == nil {
            flingVelocity = candidate
            flingVelocityTime = time
        }
    }

    private func releaseVelocity(at time: TimeInterval) -> CGVector {
        if let flingVelocityTime, time - flingVelocityTime <= 0.18, flingVelocity.speed > dragMouseVelocity.speed {
            return flingVelocity
        }

        if dragMouseVelocity.speed > 40 {
            return dragMouseVelocity
        }

        return velocity
    }

    private func step() {
        guard let window else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(max(now - lastStepTime, 1.0 / 120.0), 1.0 / 30.0)
        lastStepTime = now

        position = window.frame.origin

        let bottomPetEnabled = isBottomPetEnabled?() == true
        if let dragTargetOrigin {
            let spring = CGFloat(72)
            let damping = CGFloat(13)
            var acceleration = CGVector(dx: 0, dy: -1_850)
            acceleration.dx += (dragTargetOrigin.x - position.x) * spring - velocity.dx * damping
            // Bottom pets keep the standard physics and floor collision. Only
            // the user's vertical drag target is ignored.
            let verticalTarget = bottomPetEnabled ? position.y : dragTargetOrigin.y
            acceleration.dy += (verticalTarget - position.y) * spring - velocity.dy * damping
            velocity.dx += acceleration.dx * dt
            velocity.dy += acceleration.dy * dt
        } else {
            let acceleration = CGVector(dx: 0, dy: -1_850)
            velocity.dx *= pow(0.994, dt * 60)
            velocity.dx += acceleration.dx * dt
            velocity.dy += acceleration.dy * dt
        }

        let maxSpeed = CGFloat(2_900)
        velocity.dx = velocity.dx.clamped(to: -maxSpeed...maxSpeed)
        velocity.dy = velocity.dy.clamped(to: -maxSpeed...maxSpeed)

        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        let bodySize = CGSize(width: PetMetrics.bodySize, height: PetMetrics.bodySize)
        let bodyPosition = CGPoint(
            x: position.x + PetMetrics.bodyInsetX,
            y: position.y + PetMetrics.bodyInsetY
        )
        let adjustedBodyPosition = collide(
            bodyPosition: bodyPosition,
            in: activeScreenFrame(for: bodyPosition, bodySize: bodySize),
            bodySize: bodySize
        )
        position = CGPoint(
            x: adjustedBodyPosition.position.x - PetMetrics.bodyInsetX,
            y: adjustedBodyPosition.position.y - PetMetrics.bodyInsetY
        )

        window.setFrameOrigin(position)
        updateMouseEventPassthrough(for: window)
        updateMotionState()

        if adjustedBodyPosition.landed {
            onLand?()
        }

        updateMouseGaze(now: now)
    }

    private func updateMouseEventPassthrough(for window: NSWindow) {
        let interactionFrame = bodyFrame(for: window).insetBy(
            dx: -PetMetrics.fileDropMargin,
            dy: -PetMetrics.fileDropMargin
        )
        let shouldReceiveMouseEvents = motionState.isGrabbed || interactionFrame.contains(NSEvent.mouseLocation)
        let shouldIgnoreMouseEvents = !shouldReceiveMouseEvents

        if window.ignoresMouseEvents != shouldIgnoreMouseEvents {
            window.ignoresMouseEvents = shouldIgnoreMouseEvents
        }

        if shouldIgnoreMouseEvents, motionState.feedMouthOpen != 0 {
            motionState.feedMouthOpen = 0
        }
    }

    private func collide(bodyPosition: CGPoint, in bounds: CGRect, bodySize: CGSize) -> (position: CGPoint, landed: Bool) {
        let restitution = CGFloat(0.46)
        let floorFriction = CGFloat(0.72)
        let minX = bounds.minX
        let maxX = bounds.maxX - bodySize.width
        let minY = bounds.minY
        let maxY = bounds.maxY - bodySize.height
        var bodyPosition = bodyPosition
        var landed = false

        if bodyPosition.x < minX {
            bodyPosition.x = minX
            velocity.dx = abs(velocity.dx) * restitution
        } else if bodyPosition.x > maxX {
            bodyPosition.x = maxX
            velocity.dx = -abs(velocity.dx) * restitution
        }

        if bodyPosition.y < minY {
            bodyPosition.y = minY
            landed = velocity.dy < -120
            velocity.dy = abs(velocity.dy) * restitution
            velocity.dx *= floorFriction

            if abs(velocity.dy) < 55 {
                velocity.dy = 0
            }
            if abs(velocity.dx) < 8 {
                velocity.dx = 0
            }
        } else if bodyPosition.y > maxY {
            bodyPosition.y = maxY
            velocity.dy = -abs(velocity.dy) * restitution
        }

        return (bodyPosition, landed)
    }

    private func updateMotionState() {
        let speed = hypot(velocity.dx, velocity.dy)
        let targetRotation = (velocity.dx / 62).clamped(to: -13...13)
        let stretch = (speed / 2_600).clamped(to: 0...0.12)

        motionState.rotationDegrees = targetRotation
        motionState.stretchX = 1 + stretch
        motionState.stretchY = 1 - stretch * 0.55
    }

    private func updateMouseGaze(now: TimeInterval) {
        guard now - lastGazeUpdateTime >= 1.0 / 30.0 else { return }
        lastGazeUpdateTime = now

        guard isMouseGazeEnabled?() == true, !motionState.isGrabbed else {
            setGazeOffset(.zero)
            return
        }

        let mouse = NSEvent.mouseLocation
        let bodyCenter = CGPoint(
            x: position.x + PetMetrics.bodyInsetX + PetMetrics.bodySize / 2,
            y: position.y + PetMetrics.bodyInsetY + PetMetrics.bodySize / 2
        )
        let dx = mouse.x - bodyCenter.x
        let dy = mouse.y - bodyCenter.y
        let distance = hypot(dx, dy)
        let gazeRange = CGFloat(330)

        guard distance > 1, distance <= gazeRange else {
            setGazeOffset(.zero)
            return
        }

        let maxOffset = CGFloat(5.4)
        let strength = (distance / 90).clamped(to: 0...1)
        let target = CGSize(
            width: dx / distance * maxOffset * strength,
            height: -dy / distance * maxOffset * 0.65 * strength
        )
        setGazeOffset(target)
    }

    private func setGazeOffset(_ target: CGSize) {
        guard motionState.gazeOffset.distance(to: target) > 0.2 else { return }
        motionState.gazeOffset = target
    }

    private func activeScreenFrame(for origin: CGPoint, bodySize: CGSize) -> CGRect {
        let center = CGPoint(x: origin.x + bodySize.width / 2, y: origin.y + bodySize.height / 2)

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) }) {
            return screen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
    }

    private var bodyBoundsInWindow: CGRect {
        PetMetrics.bodyBoundsInWindow
    }

    private func bodyFrame(for window: NSWindow) -> CGRect {
        CGRect(
            x: window.frame.minX + PetMetrics.bodyInsetX,
            y: window.frame.minY + PetMetrics.bodyInsetY,
            width: PetMetrics.bodySize,
            height: PetMetrics.bodySize
        )
    }

    private func bodyInteractionFrame(for window: NSWindow) -> CGRect {
        bodyFrame(for: window).insetBy(
            dx: -PetMetrics.fileDropMargin,
            dy: -PetMetrics.fileDropMargin
        )
    }

    deinit {
        timer?.invalidate()
        if let localRightClickMonitor {
            NSEvent.removeMonitor(localRightClickMonitor)
        }
        if let globalRightClickMonitor {
            NSEvent.removeMonitor(globalRightClickMonitor)
        }
        if let inputEventRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), inputEventRunLoopSource, .commonModes)
        }
        if let inputEventTap {
            CFMachPortInvalidate(inputEventTap)
        }
    }
}

private func petInputEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<PetPhysicsController>.fromOpaque(userInfo).takeUnretainedValue()
    let eventCopy = event.copy() ?? event

    Task { @MainActor in
        controller.handleInputEventTap(type: type, event: eventCopy)
    }

    return Unmanaged.passUnretained(event)
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private extension CGSize {
    func distance(to other: CGSize) -> CGFloat {
        hypot(width - other.width, height - other.height)
    }
}

private extension CGVector {
    var speed: CGFloat {
        hypot(dx, dy)
    }
}
