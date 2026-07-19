import Foundation
import XCTest
@testable import MacBookPet

final class PetCustomizationStoreTests: XCTestCase {
    @MainActor
    func testUpdateVersionComparisonRecognizesOnlyNewerStableReleases() {
        XCTAssertTrue(AppUpdateAvailability.isNewerRelease(tagName: "v0.9.8", than: "0.9.7"))
        XCTAssertTrue(AppUpdateAvailability.isNewerRelease(tagName: "0.10.0", than: "0.9.9"))
        XCTAssertFalse(AppUpdateAvailability.isNewerRelease(tagName: "v0.9.7", than: "0.9.7"))
        XCTAssertFalse(AppUpdateAvailability.isNewerRelease(tagName: "not-a-version", than: "0.9.7"))
    }

    @MainActor
    func testCustomPetAndImportedAssetPersistAcrossStoreReload() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        let assetID = try store.importPNG(from: fixturePNGURL)
        let visualConfiguration = PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(
                    base: .importedAsset(id: assetID),
                    eyes: PetEyeModuleConfiguration(kind: .tracking)
                )
            ],
            bottomPetEnabled: true,
            gravityEnabled: false
        )

        let pet = try store.createCustomPet(
            name: "  Test Pet  ",
            visualConfiguration: visualConfiguration
        )

        XCTAssertTrue(pet.id.hasPrefix("custom:"))
        XCTAssertEqual(pet.name, "Test Pet")
        XCTAssertNotNil(store.assetURL(for: assetID))

        let reloadedStore = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        XCTAssertEqual(reloadedStore.customPet(id: pet.id)?.name, "Test Pet")
        XCTAssertEqual(
            reloadedStore.customPet(id: pet.id)?.visualConfiguration,
            visualConfiguration
        )
        XCTAssertFalse(
            reloadedStore.customPet(id: pet.id)?.visualConfiguration.resolvedGravityEnabled ?? true
        )
    }

    func testLegacyVisualConfigurationDefaultsToGravityEnabled() {
        let configuration = PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(base: .officialSkin, eyes: nil)
            ]
        )

        XCTAssertTrue(configuration.resolvedGravityEnabled)
    }

    @MainActor
    func testCustomPetCanBeUpdatedAndDeletedWithItsUnusedAsset() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        let assetID = try store.importPNG(from: fixturePNGURL)
        let visualConfiguration = PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(
                    base: .importedAsset(id: assetID),
                    eyes: nil
                )
            ]
        )
        let pet = try store.createCustomPet(
            name: "Original Name",
            visualConfiguration: visualConfiguration
        )

        try store.updateCustomPet(
            id: pet.id,
            name: "Updated Name",
            visualConfiguration: visualConfiguration
        )
        XCTAssertEqual(store.customPet(id: pet.id)?.name, "Updated Name")

        try store.deleteCustomPet(id: pet.id)
        XCTAssertNil(store.customPet(id: pet.id))
        XCTAssertNil(store.assetURL(for: assetID))

        let reloadedStore = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        XCTAssertTrue(reloadedStore.customPets.isEmpty)
    }

    @MainActor
    func testFrameAnimationAssetPersistsInFrameOrder() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        let assetID = try store.importVisualAsset(from: [fixturePNGURL, fixturePNGURL])
        let asset = try XCTUnwrap(store.importedVisualAsset(for: assetID))

        XCTAssertEqual(asset.kind, .frameAnimation)
        XCTAssertTrue(asset.isAnimated)
        XCTAssertEqual(asset.frameCount, 2)
        XCTAssertEqual(asset.frameURLs.map(\.lastPathComponent), ["0000.png", "0001.png"])

        let configuration = PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(
                    base: .importedAsset(id: assetID),
                    eyes: nil,
                    animationPlaybackRate: 1.5
                )
            ]
        )
        let pet = try store.createCustomPet(name: "Frame Pet", visualConfiguration: configuration)
        let reloadedStore = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)

        XCTAssertEqual(
            reloadedStore.customPet(id: pet.id)?.visualConfiguration.configuration(for: .normal).animationPlaybackRate,
            1.5
        )
        XCTAssertEqual(reloadedStore.importedVisualAsset(for: assetID)?.frameCount, 2)
    }

    @MainActor
    func testFrameAnimationCanBeReorderedAndReloaded() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let sourceDirectory = temporaryRoot.appendingPathComponent("sources", isDirectory: true)
        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        let sourceURLs = ["png", "jpg", "heic"].map {
            sourceDirectory.appendingPathComponent("frame.\($0)", isDirectory: false)
        }
        for sourceURL in sourceURLs {
            try fileManager.copyItem(at: fixturePNGURL, to: sourceURL)
        }

        let store = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let assetID = try store.importVisualAsset(from: sourceURLs)
        XCTAssertEqual(
            store.importedVisualAsset(for: assetID)?.frameURLs.map(\.lastPathComponent),
            ["0000.png", "0001.jpg", "0002.heic"]
        )

        try store.reorderFrames(assetID: assetID, from: 2, to: 1)
        XCTAssertEqual(
            store.importedVisualAsset(for: assetID)?.frameURLs.map(\.lastPathComponent),
            ["0000.png", "0001.heic", "0002.jpg"]
        )

        _ = try store.createCustomPet(
            name: "Reordered Frame Pet",
            visualConfiguration: PetVisualConfiguration(
                states: [
                    .normal: PetStateVisualConfiguration(
                        base: .importedAsset(id: assetID),
                        eyes: nil
                    )
                ]
            )
        )

        let reloadedStore = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        XCTAssertEqual(
            reloadedStore.importedVisualAsset(for: assetID)?.frameURLs.map(\.lastPathComponent),
            ["0000.png", "0001.heic", "0002.jpg"]
        )
    }

    @MainActor
    func testFrameAnimationCanRemoveAnIndividualFrame() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let assetID = try store.importVisualAsset(from: [fixturePNGURL, fixturePNGURL])
        XCTAssertEqual(store.importedVisualAsset(for: assetID)?.frameCount, 2)

        try store.removeFrame(assetID: assetID, at: 1)

        XCTAssertEqual(store.importedVisualAsset(for: assetID)?.frameCount, 1)
        XCTAssertThrowsError(try store.removeFrame(assetID: assetID, at: 0)) { error in
            guard case PetAssetStoreError.lastFrameRemovalUnsupported = error else {
                return XCTFail("Expected the final-frame deletion guard, got \(error)")
            }
        }
    }

    @MainActor
    func testActionAnimationAssetPersistsWithItsDefaultVisual() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let defaultAssetID = try store.importVisualAsset(from: [fixturePNGURL])
        let actionAssetID = try store.importVisualAsset(from: [fixturePNGURL, fixturePNGURL])
        let configuration = PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(
                    base: .importedAsset(id: defaultAssetID),
                    eyes: nil,
                    actionAssetID: actionAssetID,
                    actionAnimationPlaybackRate: 0.8
                )
            ]
        )

        let pet = try store.createCustomPet(name: "Action Pet", visualConfiguration: configuration)
        let reloadedStore = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let reloadedState = reloadedStore.customPet(id: pet.id)?.visualConfiguration.configuration(for: .normal)

        XCTAssertEqual(reloadedState?.actionAssetID, actionAssetID)
        XCTAssertEqual(reloadedState?.actionAnimationPlaybackRate, 0.8)
        XCTAssertNotNil(reloadedStore.importedVisualAsset(for: actionAssetID))
    }

    @MainActor
    func testMultipleActionAssetsPersistInTheirAddedOrder() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let defaultAssetID = try store.importVisualAsset(from: [fixturePNGURL])
        let firstActionID = try store.importVisualAsset(from: [fixturePNGURL])
        let secondActionID = try store.importVisualAsset(from: [fixturePNGURL, fixturePNGURL])
        var state = PetStateVisualConfiguration(
            base: .importedAsset(id: defaultAssetID),
            eyes: nil
        )
        state.appendActionAsset(firstActionID)
        state.appendActionAsset(secondActionID)
        state.actionFrequency = .high

        let pet = try store.createCustomPet(
            name: "Multiple Actions",
            visualConfiguration: PetVisualConfiguration(states: [.normal: state])
        )
        let reloadedStore = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let reloadedState = try XCTUnwrap(
            reloadedStore.customPet(id: pet.id)?.visualConfiguration.configuration(for: .normal)
        )

        XCTAssertEqual(reloadedState.resolvedActionAssetIDs, [firstActionID, secondActionID])
        XCTAssertEqual(reloadedState.resolvedActionFrequency, .high)
        XCTAssertNotNil(reloadedStore.importedVisualAsset(for: secondActionID))
    }

    @MainActor
    func testSleepingBreathPreferencePersistsForCustomPet() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let assetID = try store.importPNG(from: fixturePNGURL)
        var sleepingState = PetStateVisualConfiguration(
            base: .importedAsset(id: assetID),
            eyes: nil
        )
        sleepingState.sleepingBreathEnabled = false
        let pet = try store.createCustomPet(
            name: "No Breathing",
            visualConfiguration: PetVisualConfiguration(
                states: [
                    .normal: PetStateVisualConfiguration(
                        base: .importedAsset(id: assetID),
                        eyes: nil
                    ),
                    .sleeping: sleepingState
                ]
            )
        )

        let reloadedStore = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let reloadedState = try XCTUnwrap(
            reloadedStore.customPet(id: pet.id)?.visualConfiguration.configuration(for: .sleeping)
        )

        XCTAssertFalse(reloadedState.resolvedSleepingBreathEnabled)
    }

    func testOnlyStillImagesSupportSleepingBreath() {
        let stillImage = PetImportedVisualAsset(
            kind: .stillImage,
            imageURL: fixturePNGURL,
            frameURLs: []
        )
        let frameAnimation = PetImportedVisualAsset(
            kind: .frameAnimation,
            imageURL: fixturePNGURL,
            frameURLs: [fixturePNGURL, fixturePNGURL]
        )

        XCTAssertTrue(stillImage.supportsSleepingBreath)
        XCTAssertFalse(frameAnimation.supportsSleepingBreath)
    }

    func testLegacySleepingConfigurationDefaultsToBubbleEffect() {
        let configuration = PetStateVisualConfiguration(
            base: .officialSkin,
            eyes: nil
        )

        XCTAssertEqual(configuration.resolvedSleepingEffect, .bubbles)
    }

    @MainActor
    func testSleepingEffectPreferencePersistsForCustomPet() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let assetID = try store.importPNG(from: fixturePNGURL)
        var sleepingState = PetStateVisualConfiguration(
            base: .importedAsset(id: assetID),
            eyes: nil
        )
        sleepingState.sleepingEffect = .zzz
        let pet = try store.createCustomPet(
            name: "Zzz Effect",
            visualConfiguration: PetVisualConfiguration(
                states: [
                    .normal: PetStateVisualConfiguration(
                        base: .importedAsset(id: assetID),
                        eyes: nil
                    ),
                    .sleeping: sleepingState
                ]
            )
        )

        let reloadedStore = PetCustomizationStore(fileManager: fileManager, customRootURL: temporaryRoot)
        let reloadedState = try XCTUnwrap(
            reloadedStore.customPet(id: pet.id)?.visualConfiguration.configuration(for: .sleeping)
        )

        XCTAssertEqual(reloadedState.resolvedSleepingEffect, .zzz)
    }

    @MainActor
    func testCustomizationEntitlementIsAvailableByDefault() {
        XCTAssertTrue(FeatureEntitlementStore().isUnlocked(.petCustomization))
    }

    @MainActor
    func testAllBuiltInPetsAreUnlockedButPaidCatSkinsStayLocked() {
        let suiteName = "PetProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PetProgressStore(
            currentRuntime: 0,
            selectedPetID: PetCatalog.cube.id,
            selectedSkinID: PetCatalog.cube.skins[0].id,
            defaults: defaults
        )

        for pet in PetCatalog.pets {
            XCTAssertTrue(store.ownsPet(pet.id))
        }
        XCTAssertTrue(store.ownsSkin("cat.classic"))
        XCTAssertTrue(store.ownsSkin("cat.yellow"))
        XCTAssertFalse(store.ownsSkin("cat.grayTabby"))
        XCTAssertFalse(store.ownsSkin("cat.calico"))
        XCTAssertFalse(store.ownsSkin("cat.black"))
        XCTAssertFalse(store.ownsSkin("cat.siamese"))
        XCTAssertTrue(
            PetCatalog.cat.skins
                .filter { $0.id != "cat.classic" && $0.id != "cat.yellow" }
                .allSatisfy { $0.price > 0 }
        )
    }

    func testYellowCatOfficialDefaultsUseBakedStateArtwork() {
        let configuration = PetVisualDefaults.cat(skinID: "cat.yellow")

        XCTAssertTrue(configuration.resolvedBottomPetEnabled)
        for state in PetVisualState.allCases {
            XCTAssertNil(configuration.configuration(for: state).eyes)
        }
        XCTAssertEqual(
            configuration.configuration(for: .normal).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.1515151515151515)
        )
        XCTAssertEqual(
            configuration.configuration(for: .happy).baseOffset,
            NormalizedVisualOffset(x: 0.015151515151515152, y: 0.16666666666666663)
        )
        for state in PetVisualState.allCases {
            XCTAssertEqual(configuration.configuration(for: state).resolvedBaseScale, 1.1)
        }
    }

    func testShibaOfficialDefaultsMatchApprovedCustomPetPlacement() throws {
        XCTAssertEqual(PetCatalog.dog.name, .dog)
        XCTAssertEqual(PetCatalog.dog.skins.map(\.name), [.shibaClassic])

        let configuration = PetVisualDefaults.configuration(
            petID: PetCatalog.dog.id,
            skinID: "dog.shiba"
        )
        let normalEyes = try XCTUnwrap(configuration.configuration(for: .normal).eyes)

        XCTAssertEqual(normalEyes.kind, .shibaWatercolor)
        XCTAssertEqual(normalEyes.center.x, 0.4963699494949495)
        XCTAssertEqual(normalEyes.center.y, 0.3116911300505051)
        XCTAssertEqual(normalEyes.scale, 0.5)
        XCTAssertEqual(normalEyes.spacing, 3.676809210526315)
        XCTAssertEqual(normalEyes.resolvedPupilScale, 0.5482884457236842)
        XCTAssertEqual(
            configuration.configuration(for: .normal).baseOffset,
            NormalizedVisualOffset(x: 0.0012866436100131755, y: 0.015014273166447073)
        )
        XCTAssertEqual(
            configuration.configuration(for: .happy).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.015151515151515152)
        )
        XCTAssertEqual(
            configuration.configuration(for: .scared).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.030303030303030304)
        )
        XCTAssertEqual(
            configuration.configuration(for: .eating).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.015151515151515152)
        )
        XCTAssertEqual(
            configuration.configuration(for: .hungry).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.06060606060606061)
        )
        XCTAssertEqual(configuration.configuration(for: .normal).resolvedBaseScale, 1.15)
        XCTAssertEqual(configuration.configuration(for: .happy).resolvedBaseScale, 1.15)
        XCTAssertEqual(configuration.configuration(for: .scared).resolvedBaseScale, 1.15)
        XCTAssertEqual(configuration.configuration(for: .sleeping).resolvedBaseScale, 1.15)
        XCTAssertEqual(configuration.configuration(for: .eating).resolvedBaseScale, 1.15)
        XCTAssertEqual(configuration.configuration(for: .hungry).resolvedBaseScale, 1.1)
        XCTAssertNil(configuration.configuration(for: .happy).eyes)
        XCTAssertNil(configuration.configuration(for: .scared).eyes)
        XCTAssertNil(configuration.configuration(for: .sleeping).eyes)
        XCTAssertNil(configuration.configuration(for: .eating).eyes)
        XCTAssertNil(configuration.configuration(for: .hungry).eyes)
    }

    func testSiameseOfficialDefaultsMatchApprovedEditorPlacement() throws {
        let configuration = PetVisualDefaults.cat(skinID: "cat.siamese")
        let normal = try XCTUnwrap(configuration.configuration(for: .normal).eyes)
        let happy = try XCTUnwrap(configuration.configuration(for: .happy).eyes)
        let scared = try XCTUnwrap(configuration.configuration(for: .scared).eyes)

        XCTAssertEqual(normal.center.x, 0.43367266414141414)
        XCTAssertEqual(normal.center.y, 0.3266256313131313)
        XCTAssertEqual(happy.center.x, 0.43211410984848486)
        XCTAssertEqual(happy.center.y, 0.35108901515151514)
        XCTAssertEqual(scared.center.x, 0.4321338383838384)
        XCTAssertEqual(scared.center.y, 0.3512863005050505)
        XCTAssertEqual(normal.spacing, -2.8)
        XCTAssertEqual(happy.spacing, -2.8)
        XCTAssertEqual(scared.scale, 0.743798828125)
        XCTAssertEqual(scared.spacing, -0.1447265625000007)
        XCTAssertNil(configuration.configuration(for: .sleeping).eyes)
        XCTAssertEqual(
            configuration.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.16666666666666657)
        )
        XCTAssertNil(configuration.configuration(for: .eating).eyes)
        XCTAssertNil(configuration.configuration(for: .hungry).eyes)
    }

    func testOrangeTabbyOfficialDefaultsMatchApprovedEditorPlacement() throws {
        let configuration = PetVisualDefaults.cat(skinID: "cat.classic")
        let normal = try XCTUnwrap(configuration.configuration(for: .normal).eyes)
        let happy = try XCTUnwrap(configuration.configuration(for: .happy).eyes)
        let scared = try XCTUnwrap(configuration.configuration(for: .scared).eyes)

        XCTAssertEqual(normal.center.x, 0.49242424242424243)
        XCTAssertEqual(normal.center.y, 0.3181818181818182)
        XCTAssertEqual(normal.spacing, -1.2937959558823522)
        XCTAssertEqual(normal.resolvedOuterEyeScale, 1.2254566865808822)
        XCTAssertEqual(normal.resolvedPupilScale, 0.8321030560661764)
        XCTAssertEqual(happy.center.x, 0.4916942866161616)
        XCTAssertEqual(happy.center.y, 0.32733585858585856)
        XCTAssertEqual(happy.spacing, -0.8687040441176457)
        XCTAssertEqual(scared.scale, 0.841021369485294)
        XCTAssertEqual(scared.spacing, -0.8755974264705877)
        XCTAssertEqual(scared.resolvedColorMode, .black)
        XCTAssertNil(configuration.configuration(for: .sleeping).eyes)
        XCTAssertEqual(
            configuration.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.14393939393939387)
        )
        XCTAssertNil(configuration.configuration(for: .eating).eyes)
        XCTAssertNil(configuration.configuration(for: .hungry).eyes)
    }

    func testGrayTabbyOfficialDefaultsMatchApprovedEditorPlacement() throws {
        let configuration = PetVisualDefaults.cat(skinID: "cat.grayTabby")
        let normal = try XCTUnwrap(configuration.configuration(for: .normal).eyes)
        let happy = try XCTUnwrap(configuration.configuration(for: .happy).eyes)
        let scared = try XCTUnwrap(configuration.configuration(for: .scared).eyes)

        XCTAssertEqual(normal.center.x, 0.46894728535353536)
        XCTAssertEqual(normal.center.y, 0.19986979166666666)
        XCTAssertEqual(normal.spacing, -1.972794117647057)
        XCTAssertEqual(normal.resolvedPupilScale, 0.677734375)
        XCTAssertEqual(happy.center.x, 0.4727272727272727)
        XCTAssertEqual(happy.center.y, 0.2393939393939394)
        XCTAssertEqual(happy.spacing, -2.8)
        XCTAssertEqual(scared.center.x, 0.46888809974747475)
        XCTAssertEqual(scared.center.y, 0.22492503156565657)
        XCTAssertEqual(scared.scale, 0.7711827895220588)
        XCTAssertEqual(scared.spacing, 0.3169577205882348)
        XCTAssertNil(configuration.configuration(for: .sleeping).eyes)
        XCTAssertEqual(
            configuration.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.06060606060606061)
        )
        XCTAssertNil(configuration.configuration(for: .eating).eyes)
        XCTAssertNil(configuration.configuration(for: .hungry).eyes)
    }

    func testCalicoAndBlackOfficialDefaultsUseApprovedLayouts() throws {
        let calico = PetVisualDefaults.cat(skinID: "cat.calico")
        let calicoNormal = try XCTUnwrap(calico.configuration(for: .normal).eyes)
        let calicoEating = try XCTUnwrap(calico.configuration(for: .eating).eyes)

        XCTAssertEqual(calicoNormal.center.x, 0.4424715909090909)
        XCTAssertEqual(calicoNormal.center.y, 0.27434501262626265)
        XCTAssertEqual(calicoNormal.resolvedPupilScale, 0.6925551470588235)
        XCTAssertEqual(calicoEating.resolvedOuterEyeScale, 0.917580997242647)
        XCTAssertEqual(calicoEating.resolvedPupilScale, 0.641802619485294)
        XCTAssertNil(calico.configuration(for: .sleeping).eyes)
        XCTAssertEqual(
            calico.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.14393939393939387)
        )
        XCTAssertNil(calico.configuration(for: .hungry).eyes)

        let black = PetVisualDefaults.cat(skinID: "cat.black")
        let blackHappy = try XCTUnwrap(black.configuration(for: .happy).eyes)
        let blackScared = try XCTUnwrap(black.configuration(for: .scared).eyes)

        XCTAssertEqual(blackHappy.scale, 0.8814338235294117)
        XCTAssertEqual(blackHappy.spacing, -1.2708180147058812)
        XCTAssertEqual(blackScared.scale, 0.6742446001838235)
        XCTAssertEqual(blackScared.spacing, 0.5226102941176496)
        XCTAssertNil(black.configuration(for: .sleeping).eyes)
        XCTAssertEqual(
            black.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.20454545454545442)
        )
        XCTAssertNil(black.configuration(for: .eating).eyes)
        XCTAssertNil(black.configuration(for: .hungry).eyes)
    }

    func testScaredExpressionUsesDedicatedVisualStateAndOfficialEyes() throws {
        XCTAssertEqual(PetVisualState(expression: .scared), .scared)

        let scaredEyes = try XCTUnwrap(
            PetVisualDefaults.cube.configuration(for: .scared).eyes
        )
        XCTAssertEqual(scaredEyes.kind, .scared)
        let styles = scaredEyes.eyeStyles(for: .calm)
        XCTAssertEqual(styles.left, .chevronRight)
        XCTAssertEqual(styles.right, .chevronLeft)
    }

    @MainActor
    func testHungryPetDoesNotBecomeHappyWhenClicked() {
        let state = PetState()

        state.reactToClick(isHungry: true)
        XCTAssertEqual(state.expression, .calm)

        state.reactToClick(isHungry: false)
        XCTAssertEqual(state.expression, .happy)
    }

    func testHungryVisualExpressionOverridesNonEatingExpressions() {
        for expression in PetExpression.allCases where expression != .hungry {
            XCTAssertEqual(
                PetView.visualExpression(base: expression, isHungry: true, isEating: false),
                .hungry,
                "Hungry pets should use the hungry appearance instead of \(expression)."
            )
        }
    }

    func testEatingVisualExpressionOverridesHungryExpression() {
        XCTAssertEqual(
            PetView.visualExpression(base: .sleeping, isHungry: true, isEating: true),
            .sleeping
        )
    }

    func testFoodSatietyIncreasesWithPrice() {
        XCTAssertEqual(ShopCatalog.food(id: "food.smallCookie")?.satiety, 18)
        XCTAssertEqual(ShopCatalog.food(id: "food.energyBar")?.satiety, 38)
        XCTAssertEqual(ShopCatalog.food(id: "food.nutritionCan")?.satiety, 75)
        XCTAssertTrue(zip(ShopCatalog.foods, ShopCatalog.foods.dropFirst()).allSatisfy { cheaper, pricier in
            cheaper.price < pricier.price && cheaper.satiety < pricier.satiety
        })
    }

    @MainActor
    func testHungerStoreDecaysAndFeedsSatiety() {
        let suiteName = "PetHungerStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        let store = PetHungerStore(defaults: defaults, now: start)
        XCTAssertEqual(store.satiety, 100)
        XCTAssertFalse(store.isHungry)

        store.refresh(now: start.addingTimeInterval(10 * 3_600))
        XCTAssertEqual(store.satiety, 20)
        XCTAssertTrue(store.isHungry)

        let gained = store.feed(ShopCatalog.foods[1], now: start.addingTimeInterval(10 * 3_600 + 60))
        XCTAssertEqual(gained, 38)
        XCTAssertEqual(store.satiety, 58)
        XCTAssertFalse(store.isHungry)

        let cappedGain = store.feed(ShopCatalog.foods[2], now: start.addingTimeInterval(10 * 3_600 + 120))
        XCTAssertEqual(cappedGain, 42)
        XCTAssertEqual(store.satiety, 100)
    }

    @MainActor
    func testOldOfficialOverrideInheritsNewScaredState() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        let oldOverride = PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: PetEyeModuleConfiguration(kind: .tracking)
                )
            ]
        )
        try store.saveVisualOverride(
            oldOverride,
            petID: PetCatalog.cube.id,
            skinID: PetCatalog.cube.skins[0].id
        )

        let resolved = store.visualConfiguration(
            petID: PetCatalog.cube.id,
            skinID: PetCatalog.cube.skins[0].id,
            official: PetVisualDefaults.cube
        )
        XCTAssertEqual(resolved.configuration(for: .normal).eyes?.kind, .tracking)
        XCTAssertEqual(resolved.configuration(for: .scared).eyes?.kind, .scared)
        XCTAssertEqual(resolved.configuration(for: .eating).eyes?.kind, .eating)
    }

    @MainActor
    func testRestoringOneOfficialStatePreservesOtherStateAdjustments() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let store = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        let official = PetVisualDefaults.cube
        var customized = official

        var normal = customized.configuration(for: .normal)
        var normalEyes = try XCTUnwrap(normal.eyes)
        normalEyes.center = NormalizedVisualPoint(x: 0.2, y: 0.3)
        normal.eyes = normalEyes
        customized.setConfiguration(normal, for: .normal)

        var happy = customized.configuration(for: .happy)
        var happyEyes = try XCTUnwrap(happy.eyes)
        happyEyes.center = NormalizedVisualPoint(x: 0.8, y: 0.7)
        happy.eyes = happyEyes
        customized.setConfiguration(happy, for: .happy)

        try store.saveVisualOverride(
            customized,
            petID: PetCatalog.cube.id,
            skinID: PetCatalog.cube.skins[0].id
        )

        var restoredDraft = store.visualConfiguration(
            petID: PetCatalog.cube.id,
            skinID: PetCatalog.cube.skins[0].id,
            official: official
        )
        restoredDraft.setConfiguration(
            official.configuration(for: .happy),
            for: .happy
        )
        try store.saveVisualOverride(
            restoredDraft,
            petID: PetCatalog.cube.id,
            skinID: PetCatalog.cube.skins[0].id
        )

        let reloadedStore = PetCustomizationStore(
            fileManager: fileManager,
            customRootURL: temporaryRoot
        )
        let restored = reloadedStore.visualConfiguration(
            petID: PetCatalog.cube.id,
            skinID: PetCatalog.cube.skins[0].id,
            official: official
        )

        XCTAssertEqual(restored.configuration(for: .normal).eyes?.center.x, 0.2)
        XCTAssertEqual(restored.configuration(for: .normal).eyes?.center.y, 0.3)
        XCTAssertEqual(
            restored.configuration(for: .happy),
            official.configuration(for: .happy)
        )
    }

    func testEatingStateFallsBackToNormalForLegacyCustomConfigurations() throws {
        let normal = PetStateVisualConfiguration(
            base: .officialSkin,
            eyes: PetEyeModuleConfiguration(kind: .tracking)
        )
        let configuration = PetVisualConfiguration(states: [.normal: normal])

        XCTAssertEqual(configuration.configuration(for: .eating), normal)
        XCTAssertEqual(PetVisualDefaults.cube.configuration(for: .eating).eyes?.kind, .eating)
    }

    func testEyeAlignmentSupportsIndependentOffsetsAndLegacyData() throws {
        let legacyData = Data(
            #"{"center":{"x":0.5,"y":0.4},"kind":"tracking","scale":1,"spacing":11}"#.utf8
        )
        var configuration = try JSONDecoder().decode(
            PetEyeModuleConfiguration.self,
            from: legacyData
        )

        XCTAssertTrue(configuration.areEyesAligned)
        XCTAssertEqual(configuration.resolvedColorMode, .automatic)
        XCTAssertEqual(configuration.resolvedOuterEyeScale, 1)
        XCTAssertEqual(configuration.resolvedPupilScale, 1)
        configuration.setEyesAligned(false)
        XCTAssertFalse(configuration.areEyesAligned)
        XCTAssertEqual(configuration.leftEyeOffset, .zero)
        XCTAssertEqual(configuration.rightEyeOffset, .zero)

        configuration.leftEyeOffset = NormalizedVisualOffset(x: -0.1, y: 0.2)
        configuration.colorMode = .white
        configuration.outerEyeScale = 1.25
        configuration.pupilScale = 0.75
        let roundTripData = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(
            PetEyeModuleConfiguration.self,
            from: roundTripData
        )
        XCTAssertEqual(decoded.leftEyeOffset, NormalizedVisualOffset(x: -0.1, y: 0.2))
        XCTAssertEqual(decoded.resolvedColorMode, .white)
        XCTAssertEqual(decoded.resolvedOuterEyeScale, 1.25)
        XCTAssertEqual(decoded.resolvedPupilScale, 0.75)

        configuration.setEyesAligned(true)
        XCTAssertTrue(configuration.areEyesAligned)
        XCTAssertNil(configuration.leftEyeOffset)
        XCTAssertNil(configuration.rightEyeOffset)
    }

    func testCatDefaultEyeModuleUsesRoundEyesAndTracksThePointer() {
        let configuration = PetEyeModuleConfiguration(kind: .catDefault)

        XCTAssertEqual(configuration.eyeStyles(for: .calm).left, .round)
        XCTAssertEqual(configuration.eyeStyles(for: .calm).right, .round)
        XCTAssertTrue(configuration.followsMouse(for: .calm))
        XCTAssertTrue(configuration.allowsBlinking)
    }

    func testShibaWatercolorEyeModuleUsesItsDedicatedBlinkBehavior() {
        let configuration = PetEyeModuleConfiguration(kind: .shibaWatercolor)

        XCTAssertEqual(configuration.eyeStyles(for: .calm).left, .round)
        XCTAssertEqual(configuration.eyeStyles(for: .calm).right, .round)
        XCTAssertFalse(configuration.followsMouse(for: .calm))
        XCTAssertTrue(configuration.allowsBlinking)
    }

    func testSkinOffsetSupportsLegacyDataAndRoundTrip() throws {
        let legacyData = Data(#"{"base":{"officialSkin":{}}}"#.utf8)
        var configuration = try JSONDecoder().decode(
            PetStateVisualConfiguration.self,
            from: legacyData
        )

        XCTAssertNil(configuration.baseOffset)
        configuration.baseOffset = NormalizedVisualOffset(x: -0.1, y: 0.2)
        XCTAssertEqual(configuration.resolvedBaseScale, 1)
        configuration.baseScale = 1.15

        let roundTripData = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(
            PetStateVisualConfiguration.self,
            from: roundTripData
        )
        XCTAssertEqual(decoded.baseOffset, NormalizedVisualOffset(x: -0.1, y: 0.2))
        XCTAssertEqual(decoded.baseScale, 1.15)
    }

    private var fixturePNGURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/FrogPet.png", isDirectory: false)
    }
}
