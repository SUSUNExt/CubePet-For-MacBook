import Foundation

struct CustomPetDefinition: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var visualConfiguration: PetVisualConfiguration
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = "custom:\(UUID().uuidString.lowercased())",
        name: String,
        visualConfiguration: PetVisualConfiguration,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.visualConfiguration = visualConfiguration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var referencedAssetIDs: Set<String> {
        visualConfiguration.referencedAssetIDs
    }
}
