import Foundation

enum FoodName {
    case smallCookie
    case energyBar
    case petCola
}

struct FoodDefinition: Identifiable {
    let id: String
    let name: FoodName
    let price: Int
    let experience: Int
    let satiety: Int
}

enum ShopCatalog {
    static let foods = [
        FoodDefinition(id: "food.smallCookie", name: .smallCookie, price: 5, experience: 8, satiety: 18),
        FoodDefinition(id: "food.energyBar", name: .energyBar, price: 10, experience: 17, satiety: 38),
        // Keep the legacy ID so food files purchased before the rename remain valid.
        FoodDefinition(id: "food.nutritionCan", name: .petCola, price: 20, experience: 35, satiety: 75)
    ]

    static func food(id: String) -> FoodDefinition? {
        foods.first { $0.id == id }
    }
}
