import Carbon
import Combine
import Foundation

final class GlobalShortcutController {
    private let settings: ShortcutSettings
    private let onShortcut: @MainActor () -> Void
    private let signature = OSType(
        UInt32(ascii: "C") << 24
            | UInt32(ascii: "P") << 16
            | UInt32(ascii: "e") << 8
            | UInt32(ascii: "t")
    )
    private let hotKeyID = UInt32(1)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var cancellable: AnyCancellable?

    init(settings: ShortcutSettings, onShortcut: @escaping @MainActor () -> Void) {
        self.settings = settings
        self.onShortcut = onShortcut
        installEventHandler()
        register(shortcut: settings.shortcut)

        cancellable = settings.$shortcut
            .dropFirst()
            .sink { [weak self] shortcut in
                self?.register(shortcut: shortcut)
            }
    }

    deinit {
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let controller = Unmanaged<GlobalShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                controller.handle(hotKeyID: hotKeyID)
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func register(shortcut: KeyboardShortcutDefinition) {
        unregisterHotKey()

        let eventHotKeyID = EventHotKeyID(signature: signature, id: hotKeyID)
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        if status == noErr {
            hotKeyRef = newHotKeyRef
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func handle(hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == signature, hotKeyID.id == self.hotKeyID else { return }
        Task { @MainActor in
            onShortcut()
        }
    }
}

private extension UInt32 {
    init(ascii character: Character) {
        self = UInt32(character.asciiValue ?? 0)
    }
}
