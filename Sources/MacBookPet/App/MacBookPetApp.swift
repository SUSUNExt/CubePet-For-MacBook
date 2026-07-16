import AppKit
import SwiftUI

final class MacBookPetApp: NSObject, NSApplicationDelegate, NSSharingServiceDelegate {
    private var petWindow: PetWindow?
    private var petState: PetState?
    private var petMotionState: PetMotionState?
    private var physicsController: PetPhysicsController?
    private var musicPlaybackMonitor: MusicPlaybackMonitor?
    private var activeSharingService: NSSharingService?
    private var aboutWindowController: AboutWindowController?
    private var petCustomizationWindowController: PetCustomizationWindowController?
    private var shortcutSettingsWindowController: ShortcutSettingsWindowController?
    private var statusItemController: StatusItemController?
    private var globalShortcutController: GlobalShortcutController?
    private var ageStore: PetAgeStore?
    private var progressStore: PetProgressStore?
    private var hungerStore: PetHungerStore?
    private var customizationStore: PetCustomizationStore?
    private var featureEntitlementStore: FeatureEntitlementStore?
    private let feedSettings = FeedSettings()
    private let languageSettings = LanguageSettings()
    private let appearanceSettings = PetAppearanceSettings()
    private let menuStyleSettings = MenuStyleSettings()
    private let shortcutSettings = ShortcutSettings()
    private let launchAtLoginController = LaunchAtLoginController()

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let petState = PetState()
        let motionState = PetMotionState()
        self.petState = petState
        self.petMotionState = motionState

        let ageStore = PetAgeStore()
        self.ageStore = ageStore
        ageStore.start()
        let progressStore = PetProgressStore(
            currentRuntime: ageStore.totalRuntime,
            selectedPetID: appearanceSettings.selectedPetID,
            selectedSkinID: appearanceSettings.selectedSkinID
        )
        self.progressStore = progressStore
        progressStore.start { [weak ageStore] in
            ageStore?.totalRuntime ?? 0
        }
        let hungerStore = PetHungerStore()
        self.hungerStore = hungerStore
        hungerStore.start()
        let customizationStore = PetCustomizationStore()
        self.customizationStore = customizationStore
        let featureEntitlementStore = FeatureEntitlementStore()
        self.featureEntitlementStore = featureEntitlementStore
        appearanceSettings.ensureValidSelection(
            progress: progressStore,
            customizationStore: customizationStore,
            featureEntitlementStore: featureEntitlementStore
        )

        let contentView = PetView(
            state: petState,
            motionState: motionState,
            hungerStore: hungerStore,
            appearanceSettings: appearanceSettings,
            customizationStore: customizationStore,
            languageSettings: languageSettings
        )

        let hostingView = PetHostingView(rootView: contentView)
        hostingView.motionState = motionState
        hostingView.onFeedInteractionBegan = { [weak petState] in
            petState?.reactToFeed()
        }
        hostingView.canAcceptFeedFiles = { [weak self] urls in
            self?.canAcceptFeedFiles(urls) == true
        }
        hostingView.onFeedFiles = { [weak self, weak petState] urls in
            guard self?.handleFedItems(urls) == true else { return false }
            petState?.reactToFeed()
            return true
        }
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: PetMetrics.canvasWidth,
            height: PetMetrics.canvasHeight
        )

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let initialOrigin = NSPoint(
            x: screenFrame.midX - PetMetrics.bodySize / 2 - PetMetrics.bodyInsetX,
            y: screenFrame.midY - PetMetrics.bodySize / 2 - PetMetrics.bodyInsetY
        )

        let window = PetWindow(
            contentRect: NSRect(
                origin: initialOrigin,
                size: NSSize(width: PetMetrics.canvasWidth, height: PetMetrics.canvasHeight)
            )
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        let physicsController = PetPhysicsController(window: window, motionState: motionState)
        physicsController.isMouseGazeEnabled = { [weak petState] in
            petState?.allowsMouseGaze == true && !hungerStore.isHungry
        }
        physicsController.isBottomPetEnabled = { [appearanceSettings = self.appearanceSettings, customizationStore] in
            if appearanceSettings.selectedPetID == PetCatalog.cat.id,
               appearanceSettings.selectedSkinID == "cat.yellow" {
                return true
            }

            if let customPet = customizationStore.customPet(id: appearanceSettings.selectedPetID) {
                return customPet.visualConfiguration.resolvedBottomPetEnabled
            }

            let official = PetVisualDefaults.configuration(
                petID: appearanceSettings.selectedPetID,
                skinID: appearanceSettings.selectedSkinID
            )
            return customizationStore.visualConfiguration(
                petID: appearanceSettings.selectedPetID,
                skinID: appearanceSettings.selectedSkinID,
                official: official
            )
            .resolvedBottomPetEnabled
        }
        physicsController.onClick = { [petState] in
            petState.reactToClick(isHungry: hungerStore.isHungry)
        }
        physicsController.onGrab = { [petState] in
            petState.reactToGrab()
        }
        physicsController.onLand = { [petState] in
            petState.recoverAfterLanding()
        }
        window.physicsController = physicsController

        petWindow = window
        self.physicsController = physicsController
        petState.start()
        physicsController.start()

        let musicPlaybackMonitor = MusicPlaybackMonitor()
        musicPlaybackMonitor.onPlaybackChanged = { [weak petState] isPlaying in
            petState?.setMusicPlaying(isPlaying)
        }
        self.musicPlaybackMonitor = musicPlaybackMonitor
        musicPlaybackMonitor.start()

        let aboutWindowController = AboutWindowController(languageSettings: languageSettings)
        self.aboutWindowController = aboutWindowController
        let petCustomizationWindowController = PetCustomizationWindowController(
            customizationStore: customizationStore,
            appearanceSettings: appearanceSettings,
            progressStore: progressStore,
            languageSettings: languageSettings
        )
        self.petCustomizationWindowController = petCustomizationWindowController
        let shortcutSettingsWindowController = ShortcutSettingsWindowController(
            shortcutSettings: shortcutSettings,
            languageSettings: languageSettings
        )
        self.shortcutSettingsWindowController = shortcutSettingsWindowController

        let statusItemController = StatusItemController(
            feedSettings: feedSettings,
            languageSettings: languageSettings,
            ageStore: ageStore,
            progressStore: progressStore,
            hungerStore: hungerStore,
            appearanceSettings: appearanceSettings,
            menuStyleSettings: menuStyleSettings,
            customizationStore: customizationStore,
            featureEntitlementStore: featureEntitlementStore,
            shortcutSettings: shortcutSettings,
            launchAtLoginController: launchAtLoginController,
            onShowAbout: { [weak aboutWindowController] in
                aboutWindowController?.show()
            },
            onShowPetCustomization: { [weak petCustomizationWindowController] in
                petCustomizationWindowController?.show()
            },
            onShowShortcutSettings: { [weak shortcutSettingsWindowController] in
                shortcutSettingsWindowController?.show()
            },
            onQuit: { NSApp.terminate(nil) }
        )
        self.statusItemController = statusItemController

        window.onRightClick = { [weak statusItemController] _ in
            statusItemController?.showPetContextMenu(at: NSEvent.mouseLocation)
        }
        physicsController.onRightClick = { [weak statusItemController] _ in
            statusItemController?.showPetContextMenu(at: NSEvent.mouseLocation)
        }

        globalShortcutController = GlobalShortcutController(
            settings: shortcutSettings,
            onShortcut: { [weak statusItemController] in
                statusItemController?.showMenuFromShortcut()
            }
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        musicPlaybackMonitor?.stop()
        ageStore?.stopAndPersist()
        if let ageStore {
            progressStore?.synchronizeRuntime(ageStore.totalRuntime)
        }
        progressStore?.stop()
        hungerStore?.stop()
    }

    @MainActor
    private func canAcceptFeedFiles(_ urls: [URL]) -> Bool {
        guard let progressStore else { return false }
        let petID = appearanceSettings.selectedPetID
        let isUsableCustomPet = featureEntitlementStore?.isUnlocked(.petCustomization) == true
            && customizationStore?.customPet(id: petID) != nil

        return urls.contains { url in
            guard DesktopFoodFile.isFoodFile(url) else { return true }
            guard let payload = DesktopFoodFile.payload(at: url) else { return false }
            return progressStore.canConsumeFood(
                payload,
                for: petID,
                allowUnownedPet: isUsableCustomPet
            )
        }
    }

    @discardableResult
    @MainActor
    private func handleFedItems(_ urls: [URL]) -> Bool {
        guard let progressStore else { return false }
        let petID = appearanceSettings.selectedPetID
        let isUsableCustomPet = featureEntitlementStore?.isUnlocked(.petCustomization) == true
            && customizationStore?.customPet(id: petID) != nil
        var regularURLs: [URL] = []
        var didConsumeFood = false
        var gainedExperience = 0
        var gainedSatiety = 0

        for url in urls {
            guard DesktopFoodFile.isFoodFile(url) else {
                regularURLs.append(url)
                continue
            }

            guard
                let payload = DesktopFoodFile.payload(at: url),
                progressStore.consumeFood(
                    payload,
                    for: petID,
                    allowUnownedPet: isUsableCustomPet
                )
            else { continue }

            DesktopFoodFile.remove(url)
            didConsumeFood = true
            if let food = ShopCatalog.food(id: payload.foodID) {
                gainedExperience += food.experience
                gainedSatiety += hungerStore?.feed(food) ?? 0
            }
        }

        if gainedExperience > 0 {
            petMotionState?.showExperienceGain(gainedExperience)
        }
        if gainedSatiety > 0 {
            petMotionState?.showSatietyGain(gainedSatiety)
        }

        guard !regularURLs.isEmpty else { return didConsumeFood }

        switch feedSettings.destination {
        case .trash:
            return trashFeedItems(regularURLs) > 0 || didConsumeFood
        case .folder:
            guard let folderURL = feedSettings.folderURL else {
                if trashFeedItems(regularURLs) > 0 {
                    showMissingFeedFolderAlert()
                    return true
                }
                return didConsumeFood
            }

            if moveFeedItems(regularURLs, to: folderURL) {
                showMissingFeedFolderAlert()
            }
            return true
        case .airDrop:
            return shareFeedItemsViaAirDrop(regularURLs) || didConsumeFood
        }
    }

    @MainActor
    private func shareFeedItemsViaAirDrop(_ urls: [URL]) -> Bool {
        let items: [Any] = urls
        guard
            let service = NSSharingService(named: .sendViaAirDrop),
            service.canPerform(withItems: items)
        else {
            showAirDropUnavailableAlert()
            return false
        }

        NSApp.activate(ignoringOtherApps: true)
        activeSharingService = service
        service.delegate = self
        service.perform(withItems: items)
        return true
    }

    @MainActor
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        if activeSharingService === sharingService {
            activeSharingService = nil
        }
    }

    @MainActor
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        if activeSharingService === sharingService {
            activeSharingService = nil
        }
        NSLog("MacBookPet failed to share fed items via AirDrop: \(error.localizedDescription)")
        showAirDropUnavailableAlert()
    }

    @discardableResult
    private func trashFeedItems(_ urls: [URL]) -> Int {
        var trashedItemCount = 0

        for url in urls {
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
                trashedItemCount += 1
            } catch {
                NSLog("MacBookPet failed to move fed item to Trash: \(url.path), \(error.localizedDescription)")
            }
        }

        return trashedItemCount
    }

    private func moveFeedItems(_ urls: [URL], to folderURL: URL) -> Bool {
        var didFallbackToTrash = false

        for url in urls {
            do {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    didFallbackToTrash = trashFeedItems([url]) > 0 || didFallbackToTrash
                    continue
                }

                let destinationURL = availableDestinationURL(for: url, in: folderURL)
                try FileManager.default.moveItem(at: url, to: destinationURL)
            } catch {
                NSLog("MacBookPet failed to move fed item to folder: \(url.path), \(error.localizedDescription)")
            }
        }

        return didFallbackToTrash
    }

    private func showMissingFeedFolderAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = languageSettings.text(.folderNotFound)
        alert.informativeText = languageSettings.text(.folderNotFoundMessage)
        alert.addButton(withTitle: languageSettings.text(.ok))
        alert.runModal()
    }

    @MainActor
    private func showAirDropUnavailableAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = languageSettings.text(.airDropUnavailable)
        alert.informativeText = languageSettings.text(.airDropUnavailableMessage)
        alert.addButton(withTitle: languageSettings.text(.ok))
        alert.runModal()
    }

    private func availableDestinationURL(for sourceURL: URL, in folderURL: URL) -> URL {
        let fileManager = FileManager.default
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension
        var candidate = folderURL.appendingPathComponent(sourceURL.lastPathComponent)

        if candidate.standardizedFileURL != sourceURL.standardizedFileURL, !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        var index = 2
        while true {
            let fileName = pathExtension.isEmpty ? "\(baseName) \(index)" : "\(baseName) \(index).\(pathExtension)"
            candidate = folderURL.appendingPathComponent(fileName)

            if candidate.standardizedFileURL != sourceURL.standardizedFileURL, !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }

            index += 1
        }
    }

}
