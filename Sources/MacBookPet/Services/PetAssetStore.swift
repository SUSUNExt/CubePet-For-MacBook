import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PetImportedVisualAsset {
    enum Kind: Equatable {
        case stillImage
        case gif
        case frameAnimation
    }

    let kind: Kind
    let imageURL: URL
    let frameURLs: [URL]

    var isAnimated: Bool {
        kind != .stillImage
    }

    var supportsSleepingBreath: Bool {
        kind == .stillImage
    }

    var frameCount: Int {
        switch kind {
        case .stillImage:
            return 1
        case .gif:
            guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else { return 0 }
            return CGImageSourceGetCount(source)
        case .frameAnimation:
            return frameURLs.count
        }
    }

    var playbackDuration: TimeInterval {
        switch kind {
        case .stillImage:
            return 1
        case .frameAnimation:
            return max(Double(frameURLs.count) * 0.1, 0.1)
        case .gif:
            guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else { return 1 }
            return (0 ..< CGImageSourceGetCount(source)).reduce(0) { total, index in
                let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                let delay = (gifProperties?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                    ?? (gifProperties?[kCGImagePropertyGIFDelayTime] as? Double)
                    ?? 0.1
                return total + max(delay, 0.02)
            }
        }
    }
}

/// Shared decoded-image cache for user-provided still images and animation frames.
/// Assets are immutable between editor mutations, which makes URL-based caching safe
/// as long as callers invalidate the affected URLs before changing them on disk.
enum PetImportedImageCache {
    private static let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 160
        cache.totalCostLimit = 96 * 1_024 * 1_024
        return cache
    }()

    static func image(for url: URL) -> NSImage? {
        let key = url as NSURL
        if let image = cache.object(forKey: key) {
            return image
        }

        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: key, cost: memoryCost(of: image))
        return image
    }

    static func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    static func removeImages(for urls: [URL]) {
        for url in urls {
            removeImage(for: url)
        }
    }

    private static func memoryCost(of image: NSImage) -> Int {
        let bitmap = image.representations.compactMap { $0 as? NSBitmapImageRep }.first
        let width = bitmap?.pixelsWide ?? Int(image.size.width)
        let height = bitmap?.pixelsHigh ?? Int(image.size.height)
        return max(width * height * 4, 1)
    }
}

final class PetAssetStore {
    private static let maximumFileSize = 20 * 1_024 * 1_024
    private static let maximumPixelDimension = 4_096
    private static let supportedStillImageTypes: Set<String> = [
        UTType.png.identifier,
        UTType.jpeg.identifier,
        UTType.heic.identifier
    ]

    private let fileManager: FileManager
    private let assetsDirectoryURL: URL
    private var visualAssetsByID: [String: PetImportedVisualAsset] = [:]

    init(assetsDirectoryURL: URL, fileManager: FileManager = .default) {
        self.assetsDirectoryURL = assetsDirectoryURL
        self.fileManager = fileManager
    }

    func importVisualAsset(from sourceURLs: [URL]) throws -> String {
        guard !sourceURLs.isEmpty else {
            throw PetAssetStoreError.noImagesSelected
        }

        let validatedAssets = try sourceURLs.map(validateImage)
        let containsGIF = validatedAssets.contains { $0.typeIdentifier == UTType.gif.identifier }
        if sourceURLs.count > 1, containsGIF {
            throw PetAssetStoreError.gifCannotBeFrame
        }

        try fileManager.createDirectory(
            at: assetsDirectoryURL,
            withIntermediateDirectories: true
        )

        let assetID = UUID().uuidString.lowercased()
        visualAssetsByID.removeValue(forKey: assetID)
        if sourceURLs.count == 1 {
            let sourceURL = sourceURLs[0]
            let destinationURL = url(for: assetID, pathExtension: validatedAssets[0].pathExtension)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } else {
            let directoryURL = framesDirectoryURL(for: assetID)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            do {
                for (index, asset) in validatedAssets.enumerated() {
                    let name = String(format: "%04d", index)
                    let destinationURL = directoryURL.appendingPathComponent(
                        "\(name).\(asset.pathExtension)",
                        isDirectory: false
                    )
                    try fileManager.copyItem(at: asset.url, to: destinationURL)
                }
            } catch {
                try? fileManager.removeItem(at: directoryURL)
                throw error
            }
        }
        return assetID
    }

    func importPNG(from sourceURL: URL) throws -> String {
        try importVisualAsset(from: [sourceURL])
    }

    func visualAsset(for assetID: String) -> PetImportedVisualAsset? {
        guard Self.isValidAssetID(assetID) else { return nil }
        if let asset = visualAssetsByID[assetID] {
            return asset
        }

        if let imageURL = directAssetURL(for: assetID) {
            let kind: PetImportedVisualAsset.Kind = imageURL.pathExtension.lowercased() == "gif"
                ? .gif
                : .stillImage
            let asset = PetImportedVisualAsset(kind: kind, imageURL: imageURL, frameURLs: [])
            visualAssetsByID[assetID] = asset
            return asset
        }

        let directoryURL = framesDirectoryURL(for: assetID)
        guard let frameURLs = try? orderedFrameURLs(in: directoryURL),
        let firstFrameURL = frameURLs.first else {
            return nil
        }
        let asset = PetImportedVisualAsset(
            kind: .frameAnimation,
            imageURL: firstFrameURL,
            frameURLs: frameURLs
        )
        visualAssetsByID[assetID] = asset
        return asset
    }

    func existingURL(for assetID: String) -> URL? {
        visualAsset(for: assetID)?.imageURL
    }

    func reorderFrames(assetID: String, from sourceIndex: Int, to destinationIndex: Int) throws {
        guard Self.isValidAssetID(assetID) else {
            throw PetAssetStoreError.frameAnimationNotFound
        }

        let directoryURL = framesDirectoryURL(for: assetID)
        let frameURLs = try orderedFrameURLs(in: directoryURL)
        guard !frameURLs.isEmpty else {
            throw PetAssetStoreError.frameAnimationNotFound
        }
        guard frameURLs.indices.contains(sourceIndex), frameURLs.indices.contains(destinationIndex) else {
            throw PetAssetStoreError.frameIndexOutOfRange
        }
        guard sourceIndex != destinationIndex else { return }

        visualAssetsByID.removeValue(forKey: assetID)
        PetImportedImageCache.removeImages(for: frameURLs)

        var reorderedFrameURLs = frameURLs
        let movedFrameURL = reorderedFrameURLs.remove(at: sourceIndex)
        reorderedFrameURLs.insert(movedFrameURL, at: destinationIndex)

        let reorderID = UUID().uuidString.lowercased()
        var temporaryURLs: [URL: URL] = [:]
        for (index, frameURL) in frameURLs.enumerated() {
            let temporaryURL = directoryURL.appendingPathComponent(
                ".reorder-\(reorderID)-\(index).\(frameURL.pathExtension)",
                isDirectory: false
            )
            try fileManager.moveItem(at: frameURL, to: temporaryURL)
            temporaryURLs[frameURL] = temporaryURL
        }

        for (index, frameURL) in reorderedFrameURLs.enumerated() {
            guard let temporaryURL = temporaryURLs[frameURL] else { continue }
            let destinationURL = directoryURL.appendingPathComponent(
                String(format: "%04d.\(frameURL.pathExtension)", index),
                isDirectory: false
            )
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        }
    }

    func removeFrame(assetID: String, at index: Int) throws {
        guard Self.isValidAssetID(assetID) else {
            throw PetAssetStoreError.frameAnimationNotFound
        }

        let frameURLs = try orderedFrameURLs(in: framesDirectoryURL(for: assetID))
        guard frameURLs.count > 1 else {
            throw PetAssetStoreError.lastFrameRemovalUnsupported
        }
        guard frameURLs.indices.contains(index) else {
            throw PetAssetStoreError.frameIndexOutOfRange
        }

        visualAssetsByID.removeValue(forKey: assetID)
        PetImportedImageCache.removeImage(for: frameURLs[index])
        try fileManager.removeItem(at: frameURLs[index])
    }

    func removeAsset(id assetID: String) throws {
        guard Self.isValidAssetID(assetID) else { return }
        var cachedURLs = visualAssetsByID[assetID]?.frameURLs ?? []
        for pathExtension in ["png", "jpg", "jpeg", "heic", "gif"] {
            cachedURLs.append(url(for: assetID, pathExtension: pathExtension))
        }
        if let frameURLs = try? orderedFrameURLs(in: framesDirectoryURL(for: assetID)) {
            cachedURLs.append(contentsOf: frameURLs)
        }
        visualAssetsByID.removeValue(forKey: assetID)
        PetImportedImageCache.removeImages(for: cachedURLs)

        for pathExtension in ["png", "jpg", "jpeg", "heic", "gif"] {
            let assetURL = url(for: assetID, pathExtension: pathExtension)
            if fileManager.fileExists(atPath: assetURL.path) {
                try fileManager.removeItem(at: assetURL)
            }
        }
        let directoryURL = framesDirectoryURL(for: assetID)
        if fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.removeItem(at: directoryURL)
        }
    }

    func allAssetIDs() -> Set<String> {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: assetsDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return Set(urls.compactMap { url in
            if url.pathExtension == "frames" {
                let assetID = url.deletingPathExtension().lastPathComponent
                return Self.isValidAssetID(assetID) ? assetID : nil
            }
            let assetID = url.deletingPathExtension().lastPathComponent
            return Self.isValidAssetID(assetID) ? assetID : nil
        })
    }

    private func validateImage(at sourceURL: URL) throws -> ValidatedImage {
        let resourceValues = try sourceURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard resourceValues.isRegularFile == true else {
            throw PetAssetStoreError.notARegularFile
        }
        guard let fileSize = resourceValues.fileSize, fileSize <= Self.maximumFileSize else {
            throw PetAssetStoreError.fileTooLarge
        }

        guard
            let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
            let typeIdentifier = CGImageSourceGetType(imageSource) as String?,
            typeIdentifier == UTType.gif.identifier || Self.supportedStillImageTypes.contains(typeIdentifier),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0,
            height > 0
        else {
            throw PetAssetStoreError.invalidImage
        }

        guard width <= Self.maximumPixelDimension, height <= Self.maximumPixelDimension else {
            throw PetAssetStoreError.pixelDimensionsTooLarge
        }
        let pathExtension = sourceURL.pathExtension.lowercased()
        guard !pathExtension.isEmpty else { throw PetAssetStoreError.invalidImage }
        return ValidatedImage(
            url: sourceURL,
            typeIdentifier: typeIdentifier,
            pathExtension: pathExtension
        )
    }

    private func directAssetURL(for assetID: String) -> URL? {
        for pathExtension in ["png", "jpg", "jpeg", "heic", "gif"] {
            let candidate = url(for: assetID, pathExtension: pathExtension)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func url(for assetID: String, pathExtension: String) -> URL {
        assetsDirectoryURL.appendingPathComponent("\(assetID).\(pathExtension)", isDirectory: false)
    }

    private func framesDirectoryURL(for assetID: String) -> URL {
        assetsDirectoryURL.appendingPathComponent("\(assetID).frames", isDirectory: true)
    }

    private func orderedFrameURLs(in directoryURL: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { !$0.hasDirectoryPath && !$0.lastPathComponent.hasPrefix(".reorder-") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func isValidAssetID(_ assetID: String) -> Bool {
        UUID(uuidString: assetID) != nil && !assetID.contains("/")
    }

    private struct ValidatedImage {
        let url: URL
        let typeIdentifier: String
        let pathExtension: String
    }
}

enum PetAssetStoreError: LocalizedError {
    case notARegularFile
    case fileTooLarge
    case invalidImage
    case pixelDimensionsTooLarge
    case noImagesSelected
    case gifCannotBeFrame
    case frameAnimationNotFound
    case frameIndexOutOfRange
    case lastFrameRemovalUnsupported

    var errorDescription: String? {
        switch self {
        case .notARegularFile:
            return "The selected item is not a file."
        case .fileTooLarge:
            return "Each image file must be 20 MB or smaller."
        case .invalidImage:
            return "Choose a PNG, JPEG, HEIC, or GIF image."
        case .pixelDimensionsTooLarge:
            return "The PNG width and height must not exceed 4096 pixels."
        case .noImagesSelected:
            return "Choose at least one image."
        case .gifCannotBeFrame:
            return "A GIF cannot be combined with separate animation frames."
        case .frameAnimationNotFound:
            return "The frame animation could not be found."
        case .frameIndexOutOfRange:
            return "The selected animation frame is no longer available."
        case .lastFrameRemovalUnsupported:
            return "An animation must keep at least one frame. Clear the preview to remove it entirely."
        }
    }
}
