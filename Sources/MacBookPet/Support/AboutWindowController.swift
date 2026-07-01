import AppKit
import SwiftUI

@MainActor
final class AboutWindowController {
    private let languageSettings: LanguageSettings
    private var window: NSWindow?

    init(languageSettings: LanguageSettings) {
        self.languageSettings = languageSettings
    }

    func show() {
        let window = window ?? makeWindow()
        window.title = languageSettings.text(.aboutCubePet)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let contentView = AboutCubePetView(
            languageSettings: languageSettings,
            appIcon: loadAppIcon()
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = languageSettings.text(.aboutCubePet)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: contentView)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.center()
        self.window = window
        return window
    }

    private func loadAppIcon() -> NSImage {
        if
            let url = Bundle.main.url(forResource: "MacBookPet", withExtension: "icns"),
            let image = NSImage(contentsOf: url)
        {
            return image
        }

        return NSApp.applicationIconImage
    }
}
