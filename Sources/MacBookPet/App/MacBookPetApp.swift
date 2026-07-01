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
    private var statusItemController: StatusItemController?
    private var ageStore: PetAgeStore?
    private var progressStore: PetProgressStore?
    private let feedSettings = FeedSettings()
    private let languageSettings = LanguageSettings()
    private let appearanceSettings = PetAppearanceSettings()

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
        appearanceSettings.ensureValidSelection(progress: progressStore)

        let contentView = PetView(
            state: petState,
            motionState: motionState,
            appearanceSettings: appearanceSettings,
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
            petState?.allowsMouseGaze == true
        }
        physicsController.onClick = { [petState] in
            petState.reactToClick()
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

        statusItemController = StatusItemController(
            feedSettings: feedSettings,
            languageSettings: languageSettings,
            ageStore: ageStore,
            progressStore: progressStore,
            appearanceSettings: appearanceSettings,
            onShowAbout: { [weak aboutWindowController] in
                aboutWindowController?.show()
            },
            onQuit: { NSApp.terminate(nil) }
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
    }

    @MainActor
    private func canAcceptFeedFiles(_ urls: [URL]) -> Bool {
        guard let progressStore else { return false }
        let petID = appearanceSettings.selectedPetID

        return urls.contains { url in
            guard DesktopFoodFile.isFoodFile(url) else { return true }
            guard let payload = DesktopFoodFile.payload(at: url) else { return false }
            return progressStore.canConsumeFood(payload, for: petID)
        }
    }

    @discardableResult
    @MainActor
    private func handleFedItems(_ urls: [URL]) -> Bool {
        guard let progressStore else { return false }
        let petID = appearanceSettings.selectedPetID
        var regularURLs: [URL] = []
        var didConsumeFood = false
        var gainedExperience = 0

        for url in urls {
            guard DesktopFoodFile.isFoodFile(url) else {
                regularURLs.append(url)
                continue
            }

            guard
                let payload = DesktopFoodFile.payload(at: url),
                progressStore.consumeFood(payload, for: petID)
            else { continue }

            DesktopFoodFile.remove(url)
            didConsumeFood = true
            gainedExperience += ShopCatalog.food(id: payload.foodID)?.experience ?? 0
        }

        if gainedExperience > 0 {
            petMotionState?.showExperienceGain(gainedExperience)
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
