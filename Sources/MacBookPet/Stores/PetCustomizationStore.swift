import Combine
import Foundation

@MainActor
final class PetCustomizationStore: ObservableObject {
    @Published private(set) var visualOverrides: [String: PetVisualConfiguration] = [:]
    @Published private(set) var customPets: [CustomPetDefinition] = []
    @Published private(set) var eyePresets: [PetEyePreset] = []

    private let fileManager: FileManager
    private let configurationFileURL: URL?
    private let legacyConfigurationFileURL: URL?
    private let assetStore: PetAssetStore?

    init(
        fileManager: FileManager = .default,
        customRootURL: URL? = nil
    ) {
        self.fileManager = fileManager

        let rootURL = customRootURL ?? Self.makeRootURL(fileManager: fileManager)
        configurationFileURL = rootURL?.appendingPathComponent(
            "customization.json",
            isDirectory: false
        )
        legacyConfigurationFileURL = rootURL?.appendingPathComponent(
            "visual-configurations.json",
            isDirectory: false
        )
        assetStore = rootURL.map {
            PetAssetStore(
                assetsDirectoryURL: $0.appendingPathComponent("Assets", isDirectory: true),
                fileManager: fileManager
            )
        }

        loadDocument()
        removeOrphanedAssets()
    }

    func visualConfiguration(
        petID: String,
        skinID: String,
        official: PetVisualConfiguration
    ) -> PetVisualConfiguration {
        guard let override = visualOverrides[Self.key(petID: petID, skinID: skinID)] else {
            return official
        }
        return override.fillingMissingStates(from: official)
    }

    func customPet(id: String) -> CustomPetDefinition? {
        customPets.first { $0.id == id }
    }

    func assetURL(for assetID: String) -> URL? {
        assetStore?.existingURL(for: assetID)
    }

    func importedVisualAsset(for assetID: String) -> PetImportedVisualAsset? {
        assetStore?.visualAsset(for: assetID)
    }

    func importVisualAsset(from sourceURLs: [URL]) throws -> String {
        guard let assetStore else {
            throw PetCustomizationStoreError.applicationSupportUnavailable
        }
        return try assetStore.importVisualAsset(from: sourceURLs)
    }

    func importPNG(from sourceURL: URL) throws -> String {
        try importVisualAsset(from: [sourceURL])
    }

    func reorderFrames(assetID: String, from sourceIndex: Int, to destinationIndex: Int) throws {
        guard let assetStore else {
            throw PetCustomizationStoreError.applicationSupportUnavailable
        }
        try assetStore.reorderFrames(
            assetID: assetID,
            from: sourceIndex,
            to: destinationIndex
        )
    }

    func removeFrame(assetID: String, at index: Int) throws {
        guard let assetStore else {
            throw PetCustomizationStoreError.applicationSupportUnavailable
        }
        try assetStore.removeFrame(assetID: assetID, at: index)
    }

    func importEyePreset(from sourceURL: URL) throws -> PetEyePreset {
        guard let assetStore else {
            throw PetCustomizationStoreError.applicationSupportUnavailable
        }

        let assetID = try assetStore.importVisualAsset(from: [sourceURL])
        let filename = sourceURL.deletingPathExtension().lastPathComponent
        let preset = PetEyePreset(
            name: filename.isEmpty ? "Custom Eye" : filename,
            assetID: assetID
        )
        eyePresets.append(preset)

        do {
            try persistDocument()
            return preset
        } catch {
            eyePresets.removeAll { $0.id == preset.id }
            try? assetStore.removeAsset(id: assetID)
            throw error
        }
    }

    func deleteEyePreset(id: String) throws {
        guard let index = eyePresets.firstIndex(where: { $0.id == id }) else { return }
        let removedPreset = eyePresets.remove(at: index)

        do {
            try persistDocument()
            removeUnusedAssets(from: [removedPreset.assetID])
        } catch {
            eyePresets.insert(removedPreset, at: index)
            throw error
        }
    }

    func renameEyePreset(id: String, name: String) throws {
        guard let index = eyePresets.firstIndex(where: { $0.id == id }) else { return }
        let normalizedName = try Self.normalizedEyePresetName(name)
        let previousPreset = eyePresets[index]
        eyePresets[index].name = normalizedName

        do {
            try persistDocument()
        } catch {
            eyePresets[index] = previousPreset
            throw error
        }
    }

    @discardableResult
    func createCustomPet(
        name: String,
        visualConfiguration: PetVisualConfiguration
    ) throws -> CustomPetDefinition {
        let normalizedName = try Self.normalizedName(name)
        try validateAssets(in: visualConfiguration)
        guard case .importedAsset = visualConfiguration.configuration(for: .normal).base else {
            throw PetCustomizationStoreError.defaultImageRequired
        }

        let pet = CustomPetDefinition(
            name: normalizedName,
            visualConfiguration: visualConfiguration
        )
        customPets.append(pet)

        do {
            try persistDocument()
            return pet
        } catch {
            customPets.removeAll { $0.id == pet.id }
            throw error
        }
    }

    func updateCustomPet(
        id: String,
        name: String,
        visualConfiguration: PetVisualConfiguration
    ) throws {
        guard id.hasPrefix("custom:"), let index = customPets.firstIndex(where: { $0.id == id }) else {
            throw PetCustomizationStoreError.customPetNotFound
        }

        let normalizedName = try Self.normalizedName(name)
        try validateAssets(in: visualConfiguration)

        let previous = customPets[index]
        customPets[index].name = normalizedName
        customPets[index].visualConfiguration = visualConfiguration
        customPets[index].updatedAt = Date()

        do {
            try persistDocument()
            removeUnusedAssets(from: previous.referencedAssetIDs)
        } catch {
            customPets[index] = previous
            throw error
        }
    }

    func deleteCustomPet(id: String) throws {
        guard let index = customPets.firstIndex(where: { $0.id == id }) else { return }
        let removedPet = customPets.remove(at: index)

        do {
            try persistDocument()
            removeUnusedAssets(from: removedPet.referencedAssetIDs)
        } catch {
            customPets.insert(removedPet, at: index)
            throw error
        }
    }

    func saveVisualOverride(
        _ configuration: PetVisualConfiguration,
        petID: String,
        skinID: String
    ) throws {
        try validateAssets(in: configuration)

        let key = Self.key(petID: petID, skinID: skinID)
        let previous = visualOverrides[key]
        visualOverrides[key] = configuration

        do {
            try persistDocument()
            if let previous {
                removeUnusedAssets(from: previous.referencedAssetIDs)
            }
        } catch {
            visualOverrides[key] = previous
            throw error
        }
    }

    func resetVisualOverride(petID: String, skinID: String) throws {
        let key = Self.key(petID: petID, skinID: skinID)
        guard let previous = visualOverrides.removeValue(forKey: key) else { return }

        do {
            try persistDocument()
            removeUnusedAssets(from: previous.referencedAssetIDs)
        } catch {
            visualOverrides[key] = previous
            throw error
        }
    }

    private func loadDocument() {
        if
            let configurationFileURL,
            let data = try? Data(contentsOf: configurationFileURL),
            let document = try? JSONDecoder().decode(PetCustomizationDocument.self, from: data)
        {
            visualOverrides = document.visualOverrides
            customPets = document.customPets.filter { $0.id.hasPrefix("custom:") }
            eyePresets = document.eyePresets.filter { $0.id.hasPrefix("eye:") }
            return
        }

        guard
            let legacyConfigurationFileURL,
            let data = try? Data(contentsOf: legacyConfigurationFileURL),
            let legacyOverrides = try? JSONDecoder().decode(
                [String: PetVisualConfiguration].self,
                from: data
            )
        else { return }

        visualOverrides = legacyOverrides
    }

    private func persistDocument() throws {
        guard let configurationFileURL else {
            throw PetCustomizationStoreError.applicationSupportUnavailable
        }

        try fileManager.createDirectory(
            at: configurationFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let document = PetCustomizationDocument(
            visualOverrides: visualOverrides,
            customPets: customPets,
            eyePresets: eyePresets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: configurationFileURL, options: .atomic)
    }

    private func validateAssets(in configuration: PetVisualConfiguration) throws {
        for assetID in configuration.referencedAssetIDs where assetURL(for: assetID) == nil {
            throw PetCustomizationStoreError.assetNotFound(assetID)
        }
    }

    private func removeUnusedAssets(from candidates: Set<String>) {
        let referencedAssetIDs = allReferencedAssetIDs
        for assetID in candidates.subtracting(referencedAssetIDs) {
            try? assetStore?.removeAsset(id: assetID)
        }
    }

    private func removeOrphanedAssets() {
        guard let assetStore else { return }
        for assetID in assetStore.allAssetIDs().subtracting(allReferencedAssetIDs) {
            try? assetStore.removeAsset(id: assetID)
        }
    }

    private var allReferencedAssetIDs: Set<String> {
        let overrideAssets = visualOverrides.values.reduce(into: Set<String>()) {
            $0.formUnion($1.referencedAssetIDs)
        }
        let customPetAssets = customPets.reduce(into: overrideAssets) {
            $0.formUnion($1.referencedAssetIDs)
        }
        return eyePresets.reduce(into: customPetAssets) {
            $0.insert($1.assetID)
        }
    }

    private static func makeRootURL(fileManager: FileManager) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CubePet", isDirectory: true)
            .appendingPathComponent("Customization", isDirectory: true)
    }

    private static func key(petID: String, skinID: String) -> String {
        "\(petID)::\(skinID)"
    }

    private static func normalizedName(_ name: String) throws -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 40 else {
            throw PetCustomizationStoreError.invalidName
        }
        return normalized
    }

    private static func normalizedEyePresetName(_ name: String) throws -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 40 else {
            throw PetCustomizationStoreError.invalidEyePresetName
        }
        return normalized
    }
}

private struct PetCustomizationDocument: Codable {
    let schemaVersion: Int
    var visualOverrides: [String: PetVisualConfiguration]
    var customPets: [CustomPetDefinition]
    var eyePresets: [PetEyePreset]

    init(
        visualOverrides: [String: PetVisualConfiguration],
        customPets: [CustomPetDefinition],
        eyePresets: [PetEyePreset]
    ) {
        schemaVersion = 2
        self.visualOverrides = visualOverrides
        self.customPets = customPets
        self.eyePresets = eyePresets
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case visualOverrides
        case customPets
        case eyePresets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        visualOverrides = try container.decodeIfPresent(
            [String: PetVisualConfiguration].self,
            forKey: .visualOverrides
        ) ?? [:]
        customPets = try container.decodeIfPresent([CustomPetDefinition].self, forKey: .customPets) ?? []
        eyePresets = try container.decodeIfPresent([PetEyePreset].self, forKey: .eyePresets) ?? []
    }
}

enum PetCustomizationStoreError: LocalizedError {
    case applicationSupportUnavailable
    case invalidName
    case customPetNotFound
    case assetNotFound(String)
    case defaultImageRequired
    case invalidEyePresetName

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "The Application Support folder is unavailable."
        case .invalidName:
            return "The pet name must contain 1 to 40 characters."
        case .customPetNotFound:
            return "The custom pet could not be found."
        case let .assetNotFound(assetID):
            return "The imported image could not be found: \(assetID)"
        case .defaultImageRequired:
            return "A default-state PNG image is required."
        case .invalidEyePresetName:
            return "The eye preset name must contain 1 to 40 characters."
        }
    }
}
