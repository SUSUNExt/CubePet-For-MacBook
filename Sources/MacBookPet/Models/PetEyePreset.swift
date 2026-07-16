import Foundation

struct PetEyePreset: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    let assetID: String

    init(
        id: String = "eye:\(UUID().uuidString.lowercased())",
        name: String,
        assetID: String
    ) {
        self.id = id
        self.name = name
        self.assetID = assetID
    }
}
