import AppKit
import Carbon
import Foundation

struct KeyboardShortcutDefinition: Codable, Equatable {
    static let defaultShortcut = KeyboardShortcutDefinition(
        keyCode: UInt32(kVK_ANSI_P),
        carbonModifiers: UInt32(controlKey | optionKey),
        keyName: "P"
    )

    let keyCode: UInt32
    let carbonModifiers: UInt32
    let keyName: String

    var displayString: String {
        "\(modifierDisplayString)\(keyName)"
    }

    var isValid: Bool {
        keyCode != UInt32(kVK_Escape) && carbonModifiers != 0 && !keyName.isEmpty
    }

    private var modifierDisplayString: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 {
            parts.append("Control")
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }
        if carbonModifiers & UInt32(cmdKey) != 0 {
            parts.append("Command")
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }
        return parts.isEmpty ? "" : "\(parts.joined(separator: " + ")) + "
    }

    static func from(event: NSEvent) -> KeyboardShortcutDefinition? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else { return nil }
        guard let keyName = keyName(for: event), !keyName.isEmpty else { return nil }

        return KeyboardShortcutDefinition(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers,
            keyName: keyName
        )
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        return modifiers
    }

    private static func keyName(for event: NSEvent) -> String? {
        if let namedKey = namedKey(for: event.keyCode) {
            return namedKey
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return nil
        }

        return characters.uppercased()
    }

    private static func namedKey(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Space: "Space"
        case kVK_Delete: "Delete"
        case kVK_Escape: "Escape"
        case kVK_ForwardDelete: "Forward Delete"
        case kVK_LeftArrow: "Left Arrow"
        case kVK_RightArrow: "Right Arrow"
        case kVK_DownArrow: "Down Arrow"
        case kVK_UpArrow: "Up Arrow"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default: nil
        }
    }
}
