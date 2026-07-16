import AppKit
import UniformTypeIdentifiers

@MainActor
enum PetImagePicker {
    static func chooseImages(title: String, prompt: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        return panel.runModal() == .OK ? panel.urls : nil
    }

    static func chooseGIF(title: String, prompt: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.allowedContentTypes = [.gif]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.urls : nil
    }

    static func chooseEyeImage(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseAnimationFrames(title: String, prompt: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        return panel.runModal() == .OK ? panel.urls : nil
    }
}
