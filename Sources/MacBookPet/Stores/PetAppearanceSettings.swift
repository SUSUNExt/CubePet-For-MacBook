import Combine
import Foundation

final class PetAppearanceSettings: ObservableObject {
    private static let selectedPetKey = "MacBookPet.selectedPet"
    private static let selectedSkinKey = "MacBookPet.selectedSkin"

    @Published private(set) var selectedPetID: String
    @Published private(set) var selectedSkinID: String

    init() {
        selectedPetID = UserDefaults.standard.string(forKey: Self.selectedPetKey) ?? PetCatalog.cube.id
        selectedSkinID = UserDefaults.standard.string(forKey: Self.selectedSkinKey) ?? PetCatalog.cube.skins[0].id
    }

    var selectedPet: PetDefinition {
        PetCatalog.pet(id: selectedPetID) ?? PetCatalog.cube
    }

    var selectedSkin: PetSkinDefinition {
        selectedPet.skin(id: selectedSkinID) ?? selectedPet.skins[0]
    }

    @MainActor
    func ensureValidSelection(progress: PetProgressStore) {
        guard
            progress.ownsPet(selectedPetID),
            let skin = selectedPet.skin(id: selectedSkinID),
            progress.ownsSkin(skin.id),
            skin.isUnlocked(at: progress.level(for: selectedPetID))
        else {
            saveSelection(petID: PetCatalog.cube.id, skinID: PetCatalog.cube.skins[0].id)
            return
        }
    }

    @discardableResult
    @MainActor
    func selectSkin(id: String, progress: PetProgressStore) -> Bool {
        guard
            let skin = selectedPet.skin(id: id),
            progress.ownsSkin(skin.id),
            skin.isUnlocked(at: progress.level(for: selectedPetID))
        else { return false }

        saveSelection(petID: selectedPet.id, skinID: skin.id)
        return true
    }

    @discardableResult
    @MainActor
    func selectPet(id: String, progress: PetProgressStore) -> Bool {
        guard let pet = PetCatalog.pet(id: id), progress.ownsPet(id) else { return false }

        let savedSkinID = UserDefaults.standard.string(forKey: skinKey(for: pet.id))
        let savedSkin = savedSkinID.flatMap { pet.skin(id: $0) }
        let skin = savedSkin.map { progress.ownsSkin($0.id) && $0.isUnlocked(at: progress.level(for: id)) } == true
            ? savedSkin!
            : pet.skins.first { progress.ownsSkin($0.id) && $0.isUnlocked(at: progress.level(for: id)) } ?? pet.skins[0]
        saveSelection(petID: pet.id, skinID: skin.id)
        return true
    }

    private func saveSelection(petID: String, skinID: String) {
        selectedPetID = petID
        selectedSkinID = skinID
        UserDefaults.standard.set(petID, forKey: Self.selectedPetKey)
        UserDefaults.standard.set(skinID, forKey: Self.selectedSkinKey)
        UserDefaults.standard.set(skinID, forKey: skinKey(for: petID))
    }

    private func skinKey(for petID: String) -> String {
        "MacBookPet.selectedSkin.\(petID)"
    }
}
