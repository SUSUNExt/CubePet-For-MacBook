import AppKit
import Combine

enum MenuStyle: String, CaseIterable, Hashable {
    case `default`
    case liquidGlass
    case dark
    case light

    static let selectableCases: [MenuStyle] = [.default, .dark, .light]

    var menuAppearance: NSAppearance? {
        switch self {
        case .default:
            nil
        case .liquidGlass:
            NSAppearance(named: .vibrantLight)
        case .dark:
            NSAppearance(named: .darkAqua)
        case .light:
            NSAppearance(named: .aqua)
        }
    }
}

final class MenuStyleSettings: ObservableObject {
    private static let selectedStyleKey = "MacBookPet.menuStyle"

    @Published private(set) var style: MenuStyle

    init() {
        let rawValue = UserDefaults.standard.string(forKey: Self.selectedStyleKey)
        let storedStyle = rawValue.flatMap(MenuStyle.init(rawValue:)) ?? .default
        style = storedStyle == .liquidGlass ? .default : storedStyle
        if storedStyle == .liquidGlass {
            UserDefaults.standard.set(MenuStyle.default.rawValue, forKey: Self.selectedStyleKey)
        }
    }

    func select(_ style: MenuStyle) {
        let resolvedStyle = style == .liquidGlass ? .default : style
        self.style = resolvedStyle
        UserDefaults.standard.set(resolvedStyle.rawValue, forKey: Self.selectedStyleKey)
    }
}
