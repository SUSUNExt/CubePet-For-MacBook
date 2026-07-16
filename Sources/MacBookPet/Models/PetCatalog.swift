import AppKit

enum PetSkinName {
    case classic
    case blue
    case green
    case red
    case pink
    case frogClassic
    case catClassic
    case catGrayTabby
    case catCalico
    case catBlack
    case catSiamese
    case catYellow
}

enum PetName {
    case cube
    case frog
    case cat
}

enum PetVisualKind {
    case cube
    case frog
    case cat
}

struct PetSkinDefinition: Identifiable {
    let id: String
    let name: PetSkinName
    let color: NSColor
    let unlockLevel: Int
    let price: Int

    func isUnlocked(at level: Int) -> Bool {
        level >= unlockLevel
    }
}

struct PetDefinition: Identifiable {
    let id: String
    let name: PetName
    let visualKind: PetVisualKind
    let price: Int
    let skins: [PetSkinDefinition]

    func skin(id: String) -> PetSkinDefinition? {
        skins.first { $0.id == id }
    }
}

enum PetCatalog {
    static let cube = PetDefinition(
        id: "cube",
        name: .cube,
        visualKind: .cube,
        price: 0,
        skins: [
            PetSkinDefinition(
                id: "cube.classic",
                name: .classic,
                color: .black,
                unlockLevel: 1,
                price: 0
            ),
            PetSkinDefinition(
                id: "cube.blue",
                name: .blue,
                color: NSColor(srgbRed: 0.12, green: 0.40, blue: 0.90, alpha: 1),
                unlockLevel: 2,
                price: 40
            ),
            PetSkinDefinition(
                id: "cube.green",
                name: .green,
                color: NSColor(srgbRed: 0.10, green: 0.68, blue: 0.34, alpha: 1),
                unlockLevel: 3,
                price: 80
            ),
            PetSkinDefinition(
                id: "cube.red",
                name: .red,
                color: NSColor(srgbRed: 0.88, green: 0.16, blue: 0.18, alpha: 1),
                unlockLevel: 5,
                price: 160
            ),
            PetSkinDefinition(
                id: "cube.pink",
                name: .pink,
                color: NSColor(srgbRed: 0.96, green: 0.38, blue: 0.66, alpha: 1),
                unlockLevel: 8,
                price: 300
            )
        ]
    )

    static let frog = PetDefinition(
        id: "frog",
        name: .frog,
        visualKind: .frog,
        price: 250,
        skins: [
            PetSkinDefinition(
                id: "frog.classic",
                name: .frogClassic,
                color: NSColor(srgbRed: 0.39, green: 0.48, blue: 0.16, alpha: 1),
                unlockLevel: 1,
                price: 0
            )
        ]
    )

    static let cat = PetDefinition(
        id: "cat",
        name: .cat,
        visualKind: .cat,
        price: 0,
        skins: [
            PetSkinDefinition(
                id: "cat.classic",
                name: .catClassic,
                color: NSColor(srgbRed: 0.94, green: 0.44, blue: 0.08, alpha: 1),
                unlockLevel: 1,
                price: 0
            ),
            PetSkinDefinition(
                id: "cat.grayTabby",
                name: .catGrayTabby,
                color: NSColor(srgbRed: 0.67, green: 0.62, blue: 0.54, alpha: 1),
                unlockLevel: 1,
                price: 30
            ),
            PetSkinDefinition(
                id: "cat.calico",
                name: .catCalico,
                color: NSColor(srgbRed: 0.91, green: 0.49, blue: 0.12, alpha: 1),
                unlockLevel: 1,
                price: 30
            ),
            PetSkinDefinition(
                id: "cat.black",
                name: .catBlack,
                color: NSColor(srgbRed: 0.07, green: 0.06, blue: 0.05, alpha: 1),
                unlockLevel: 1,
                price: 30
            ),
            PetSkinDefinition(
                id: "cat.siamese",
                name: .catSiamese,
                color: NSColor(srgbRed: 0.82, green: 0.72, blue: 0.56, alpha: 1),
                unlockLevel: 1,
                price: 30
            ),
            PetSkinDefinition(
                id: "cat.yellow",
                name: .catYellow,
                color: NSColor(srgbRed: 0.96, green: 0.66, blue: 0.14, alpha: 1),
                unlockLevel: 1,
                price: 0
            )
        ]
    )

    static let pets = [cube, frog, cat]

    static func pet(id: String) -> PetDefinition? {
        pets.first { $0.id == id }
    }
}
