import Foundation
import ImageIO
import UniformTypeIdentifiers

final class PetAssetStore {
    private static let maximumFileSize = 20 * 1_024 * 1_024
    private static let maximumPixelDimension = 4_096

    private let fileManager: FileManager
    private let assetsDirectoryURL: URL

    init(assetsDirectoryURL: URL, fileManager: FileManager = .default) {
        self.assetsDirectoryURL = assetsDirectoryURL
        self.fileManager = fileManager
    }

    func importPNG(from sourceURL: URL) throws -> String {
        let resourceValues = try sourceURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard resourceValues.isRegularFile == true else {
            throw PetAssetStoreError.notARegularFile
        }
        guard let fileSize = resourceValues.fileSize, fileSize <= Self.maximumFileSize else {
            throw PetAssetStoreError.fileTooLarge
        }

        guard
            let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
            CGImageSourceGetType(imageSource) as String? == UTType.png.identifier,
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0,
            height > 0
        else {
            throw PetAssetStoreError.invalidPNG
        }

        guard width <= Self.maximumPixelDimension, height <= Self.maximumPixelDimension else {
            throw PetAssetStoreError.pixelDimensionsTooLarge
        }

        try fileManager.createDirectory(
            at: assetsDirectoryURL,
            withIntermediateDirectories: true
        )

        let assetID = UUID().uuidString.lowercased()
        let destinationURL = url(for: assetID)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return assetID
    }

    func existingURL(for assetID: String) -> URL? {
        guard Self.isValidAssetID(assetID) else { return nil }
        let assetURL = url(for: assetID)
        return fileManager.fileExists(atPath: assetURL.path) ? assetURL : nil
    }

    func removeAsset(id assetID: String) throws {
        guard let assetURL = existingURL(for: assetID) else { return }
        try fileManager.removeItem(at: assetURL)
    }

    func allAssetIDs() -> Set<String> {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: assetsDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return Set(
            urls.compactMap { url in
                guard url.pathExtension.lowercased() == "png" else { return nil }
                let assetID = url.deletingPathExtension().lastPathComponent
                return Self.isValidAssetID(assetID) ? assetID : nil
            }
        )
    }

    private func url(for assetID: String) -> URL {
        assetsDirectoryURL.appendingPathComponent("\(assetID).png", isDirectory: false)
    }

    private static func isValidAssetID(_ assetID: String) -> Bool {
        UUID(uuidString: assetID) != nil && !assetID.contains("/")
    }
}

enum PetAssetStoreError: LocalizedError {
    case notARegularFile
    case fileTooLarge
    case invalidPNG
    case pixelDimensionsTooLarge

    var errorDescription: String? {
        switch self {
        case .notARegularFile:
            return "The selected item is not a file."
        case .fileTooLarge:
            return "The PNG file must be 20 MB or smaller."
        case .invalidPNG:
            return "The selected file is not a valid PNG image."
        case .pixelDimensionsTooLarge:
            return "The PNG width and height must not exceed 4096 pixels."
        }
    }
}
