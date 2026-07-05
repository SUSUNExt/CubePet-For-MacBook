import AppKit
import SwiftUI

@MainActor
final class PetCustomizationWindowController {
    private let customizationStore: PetCustomizationStore
    private let appearanceSettings: PetAppearanceSettings
    private let progressStore: PetProgressStore
    private let languageSettings: LanguageSettings
    private var window: NSWindow?

    init(
        customizationStore: PetCustomizationStore,
        appearanceSettings: PetAppearanceSettings,
        progressStore: PetProgressStore,
        languageSettings: LanguageSettings
    ) {
        self.customizationStore = customizationStore
        self.appearanceSettings = appearanceSettings
        self.progressStore = progressStore
        self.languageSettings = languageSettings
    }

    func show() {
        let rootView = PetCustomizationEditorView(
            customizationStore: customizationStore,
            appearanceSettings: appearanceSettings,
            progressStore: progressStore,
            languageSettings: languageSettings
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = self.window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = languageSettings.text(.petCustomization)
        window.contentMinSize = NSSize(width: 820, height: 600)
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("PetCustomizationWindow")
        if self.window == nil {
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
