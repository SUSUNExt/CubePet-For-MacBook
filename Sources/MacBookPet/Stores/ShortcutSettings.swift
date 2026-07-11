import Combine
import Foundation

final class ShortcutSettings: ObservableObject {
    private static let shortcutKey = "MacBookPet.menuShortcut"

    @Published var shortcut: KeyboardShortcutDefinition {
        didSet {
            saveShortcut()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: Self.shortcutKey),
            let savedShortcut = try? JSONDecoder().decode(KeyboardShortcutDefinition.self, from: data),
            savedShortcut.isValid
        {
            shortcut = savedShortcut
        } else {
            shortcut = .defaultShortcut
        }
    }

    func restoreDefault() {
        shortcut = .defaultShortcut
    }

    private func saveShortcut() {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: Self.shortcutKey)
    }
}
