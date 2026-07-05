import SwiftUI

enum PetEditorTarget: Hashable {
    case currentAppearance
    case official(petID: String, skinID: String)
    case custom(String)
    case new
}

struct PetCustomizationSidebarView: View {
    @Binding var selection: PetEditorTarget?

    @ObservedObject var progressStore: PetProgressStore
    @ObservedObject var customizationStore: PetCustomizationStore
    @ObservedObject var languageSettings: LanguageSettings

    @State private var expandedPetIDs: Set<String> = []

    var body: some View {
        List(selection: $selection) {
            Label(label(.currentAppearance), systemImage: "pawprint")
                .tag(PetEditorTarget.currentAppearance)

            Divider()

            Section(label(.unlockedPets)) {
                ForEach(unlockedPets) { pet in
                    DisclosureGroup(
                        isExpanded: expansionBinding(for: pet.id)
                    ) {
                        ForEach(pet.skins) { skin in
                            skinRow(pet: pet, skin: skin)
                        }
                    } label: {
                        Label(
                            languageSettings.petName(pet.name),
                            systemImage: sidebarIcon(for: pet.visualKind)
                        )
                    }
                }
            }

            Divider()

            Section(label(.customPets)) {
                ForEach(customizationStore.customPets) { pet in
                    Label(pet.name, systemImage: "photo")
                        .tag(PetEditorTarget.custom(pet.id))
                }

                Label(label(.newPet), systemImage: "plus")
                    .tag(PetEditorTarget.new)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180, idealWidth: 210, maxWidth: 250, maxHeight: .infinity)
    }

    private var unlockedPets: [PetDefinition] {
        PetCatalog.pets.filter { progressStore.ownsPet($0.id) }
    }

    @ViewBuilder
    private func skinRow(pet: PetDefinition, skin: PetSkinDefinition) -> some View {
        if progressStore.ownsSkin(skin.id) {
            Label(
                languageSettings.skinName(skin.name),
                systemImage: "paintpalette"
            )
            .tag(PetEditorTarget.official(petID: pet.id, skinID: skin.id))
        } else {
            Label(
                languageSettings.skinName(skin.name),
                systemImage: "lock.fill"
            )
            .foregroundStyle(.tertiary)
            .disabled(true)
            .allowsHitTesting(false)
        }
    }

    private func expansionBinding(for petID: String) -> Binding<Bool> {
        Binding(
            get: { expandedPetIDs.contains(petID) },
            set: { isExpanded in
                if isExpanded {
                    expandedPetIDs.insert(petID)
                } else {
                    expandedPetIDs.remove(petID)
                }
            }
        )
    }

    private func sidebarIcon(for visualKind: PetVisualKind) -> String {
        switch visualKind {
        case .cube: "square.fill"
        case .frog: "leaf.fill"
        case .cat: "pawprint.fill"
        }
    }

    private func label(_ key: PetCustomizationText) -> String {
        languageSettings.customizationText(key)
    }
}
