import Foundation
import XCTest
@testable import MacBookPet

final class PetCustomizationStoreTests: XCTestCase {
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
            ]
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
        XCTAssertFalse(store.ownsSkin("cat.grayTabby"))
        XCTAssertFalse(store.ownsSkin("cat.calico"))
        XCTAssertFalse(store.ownsSkin("cat.black"))
        XCTAssertFalse(store.ownsSkin("cat.siamese"))
        XCTAssertTrue(PetCatalog.cat.skins.dropFirst().allSatisfy { $0.price > 0 })
    }

    func testSiameseOfficialDefaultsMatchApprovedEditorPlacement() throws {
        let configuration = PetVisualDefaults.cat(skinID: "cat.siamese")
        let normal = try XCTUnwrap(configuration.configuration(for: .normal).eyes)
        let happy = try XCTUnwrap(configuration.configuration(for: .happy).eyes)
        let scared = try XCTUnwrap(configuration.configuration(for: .scared).eyes)
        let sleeping = try XCTUnwrap(configuration.configuration(for: .sleeping).eyes)
        let eating = try XCTUnwrap(configuration.configuration(for: .eating).eyes)

        XCTAssertEqual(normal.center.x, 0.43367266414141414)
        XCTAssertEqual(normal.center.y, 0.3266256313131313)
        XCTAssertEqual(happy.center.x, 0.43211410984848486)
        XCTAssertEqual(happy.center.y, 0.35108901515151514)
        XCTAssertEqual(scared.center.x, 0.4321338383838384)
        XCTAssertEqual(scared.center.y, 0.3512863005050505)
        XCTAssertEqual(sleeping.center.x, 0.43406723484848486)
        XCTAssertEqual(sleeping.center.y, 0.3385022095959596)
        XCTAssertEqual(eating.kind, .eating)
        XCTAssertEqual(eating.center.x, normal.center.x)
        XCTAssertEqual(eating.center.y, normal.center.y)
        XCTAssertEqual(normal.spacing, -2.8)
        XCTAssertEqual(happy.spacing, -2.8)
        XCTAssertEqual(scared.scale, 0.743798828125)
        XCTAssertEqual(scared.spacing, -0.1447265625000007)
        XCTAssertEqual(sleeping.spacing, -2.8)
        XCTAssertEqual(
            configuration.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.16666666666666657)
        )
    }

    func testOrangeTabbyOfficialDefaultsMatchApprovedEditorPlacement() throws {
        let configuration = PetVisualDefaults.cat(skinID: "cat.classic")
        let normal = try XCTUnwrap(configuration.configuration(for: .normal).eyes)
        let happy = try XCTUnwrap(configuration.configuration(for: .happy).eyes)
        let scared = try XCTUnwrap(configuration.configuration(for: .scared).eyes)
        let sleeping = try XCTUnwrap(configuration.configuration(for: .sleeping).eyes)
        let eating = try XCTUnwrap(configuration.configuration(for: .eating).eyes)
        let hungry = try XCTUnwrap(configuration.configuration(for: .hungry).eyes)

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
        XCTAssertEqual(sleeping.kind, .sleeping)
        XCTAssertEqual(
            configuration.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.14393939393939387)
        )
        XCTAssertEqual(eating.kind, .eating)
        XCTAssertEqual(hungry.kind, .hungry)
    }

    func testGrayTabbyOfficialDefaultsMatchApprovedEditorPlacement() throws {
        let configuration = PetVisualDefaults.cat(skinID: "cat.grayTabby")
        let normal = try XCTUnwrap(configuration.configuration(for: .normal).eyes)
        let happy = try XCTUnwrap(configuration.configuration(for: .happy).eyes)
        let scared = try XCTUnwrap(configuration.configuration(for: .scared).eyes)
        let sleeping = try XCTUnwrap(configuration.configuration(for: .sleeping).eyes)
        let eating = try XCTUnwrap(configuration.configuration(for: .eating).eyes)
        let hungry = try XCTUnwrap(configuration.configuration(for: .hungry).eyes)

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
        XCTAssertEqual(sleeping.kind, .sleeping)
        XCTAssertEqual(
            configuration.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.06060606060606061)
        )
        XCTAssertEqual(eating.kind, .eating)
        XCTAssertEqual(hungry.kind, .hungry)
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
        XCTAssertEqual(
            calico.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.14393939393939387)
        )

        let black = PetVisualDefaults.cat(skinID: "cat.black")
        let blackHappy = try XCTUnwrap(black.configuration(for: .happy).eyes)
        let blackScared = try XCTUnwrap(black.configuration(for: .scared).eyes)

        XCTAssertEqual(blackHappy.scale, 0.8814338235294117)
        XCTAssertEqual(blackHappy.spacing, -1.2708180147058812)
        XCTAssertEqual(blackScared.scale, 0.6742446001838235)
        XCTAssertEqual(blackScared.spacing, 0.5226102941176496)
        XCTAssertEqual(
            black.configuration(for: .sleeping).baseOffset,
            NormalizedVisualOffset(x: 0, y: 0.20454545454545442)
        )
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

    func testEatingVisualExpressionOverridesHungryExpression() {
        XCTAssertEqual(
            PetView.visualExpression(base: .calm, isHungry: true, isEating: false),
            .hungry
        )
        XCTAssertEqual(
            PetView.visualExpression(base: .calm, isHungry: true, isEating: true),
            .calm
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

    func testSkinOffsetSupportsLegacyDataAndRoundTrip() throws {
        let legacyData = Data(#"{"base":{"officialSkin":{}}}"#.utf8)
        var configuration = try JSONDecoder().decode(
            PetStateVisualConfiguration.self,
            from: legacyData
        )

        XCTAssertNil(configuration.baseOffset)
        configuration.baseOffset = NormalizedVisualOffset(x: -0.1, y: 0.2)

        let roundTripData = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(
            PetStateVisualConfiguration.self,
            from: roundTripData
        )
        XCTAssertEqual(decoded.baseOffset, NormalizedVisualOffset(x: -0.1, y: 0.2))
    }

    private var fixturePNGURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/FrogPet.png", isDirectory: false)
    }
}
