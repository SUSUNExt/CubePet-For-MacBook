import AppKit
import Foundation

struct FoodFilePayload: Codable {
    static let currentVersion = 1

    let version: Int
    let foodID: String
    let token: String
}

struct CreatedDesktopFood {
    let url: URL
    let payload: FoodFilePayload
}

enum DesktopFoodFile {
    static let pathExtension = "mbpetfood"
    private static let maximumPayloadSize = 4_096

    static func create(food: FoodDefinition, displayName: String) throws -> CreatedDesktopFood {
        let fileManager = FileManager.default
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let payload = FoodFilePayload(
            version: FoodFilePayload.currentVersion,
            foodID: food.id,
            token: UUID().uuidString
        )
        let data = try JSONEncoder().encode(payload)
        let fileURL = availableURL(named: displayName, in: desktopURL, fileManager: fileManager)
        try data.write(to: fileURL, options: .withoutOverwriting)

        if !NSWorkspace.shared.setIcon(foodIcon(for: food.name), forFile: fileURL.path) {
            NSLog("MacBookPet could not set the food icon for %@", fileURL.path)
        }

        return CreatedDesktopFood(url: fileURL, payload: payload)
    }

    static func isFoodFile(_ url: URL) -> Bool {
        url.pathExtension.caseInsensitiveCompare(pathExtension) == .orderedSame
    }

    static func payload(at url: URL) -> FoodFilePayload? {
        guard isFoodFile(url) else { return nil }

        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
            values.isRegularFile == true,
            let fileSize = values.fileSize,
            fileSize <= maximumPayloadSize,
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(FoodFilePayload.self, from: data),
            payload.version == FoodFilePayload.currentVersion
        else { return nil }

        return payload
    }

    static func remove(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            NSLog("MacBookPet could not remove consumed food %@: %@", url.path, error.localizedDescription)
        }
    }

    private static func availableURL(named displayName: String, in folderURL: URL, fileManager: FileManager) -> URL {
        var index = 1

        while true {
            let suffix = index == 1 ? "" : " \(index)"
            let candidate = folderURL
                .appendingPathComponent("\(displayName)\(suffix)")
                .appendingPathExtension(pathExtension)

            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private static func foodIcon(for name: FoodName) -> NSImage {
        switch name {
        case .smallCookie:
            cookieIcon()
        case .energyBar:
            energyBarIcon()
        case .petCola:
            petColaIcon()
        }
    }

    private static func makeIcon(drawing: () -> Void) -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        drawing()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func cookieIcon() -> NSImage {
        makeIcon {
            let cookieRect = NSRect(x: 48, y: 48, width: 416, height: 416)
            NSColor(calibratedRed: 0.76, green: 0.45, blue: 0.20, alpha: 1).setFill()
            NSBezierPath(ovalIn: cookieRect).fill()

            NSColor(calibratedRed: 0.92, green: 0.64, blue: 0.31, alpha: 1).setFill()
            NSBezierPath(ovalIn: cookieRect.insetBy(dx: 18, dy: 18)).fill()

            NSColor(calibratedRed: 0.25, green: 0.12, blue: 0.06, alpha: 1).setFill()
            for point in [
                NSPoint(x: 170, y: 340),
                NSPoint(x: 320, y: 360),
                NSPoint(x: 380, y: 245),
                NSPoint(x: 260, y: 260),
                NSPoint(x: 145, y: 205),
                NSPoint(x: 300, y: 135)
            ] {
                NSBezierPath(ovalIn: NSRect(x: point.x - 24, y: point.y - 24, width: 48, height: 48)).fill()
            }
        }
    }

    private static func energyBarIcon() -> NSImage {
        makeIcon {
            let barRect = NSRect(x: 62, y: 112, width: 388, height: 288)
            NSColor(calibratedRed: 0.25, green: 0.10, blue: 0.045, alpha: 1).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 42, yRadius: 42).fill()

            let horizontalInset: CGFloat = 22
            let verticalInset: CGFloat = 20
            let gap: CGFloat = 12
            let squareWidth = (barRect.width - horizontalInset * 2 - gap * 2) / 3
            let squareHeight = (barRect.height - verticalInset * 2 - gap) / 2

            for row in 0..<2 {
                for column in 0..<3 {
                    let square = NSRect(
                        x: barRect.minX + horizontalInset + CGFloat(column) * (squareWidth + gap),
                        y: barRect.minY + verticalInset + CGFloat(row) * (squareHeight + gap),
                        width: squareWidth,
                        height: squareHeight
                    )
                    NSColor(calibratedRed: 0.48, green: 0.23, blue: 0.10, alpha: 1).setFill()
                    NSBezierPath(roundedRect: square, xRadius: 20, yRadius: 20).fill()

                    NSColor(calibratedRed: 0.62, green: 0.34, blue: 0.16, alpha: 1).setStroke()
                    let highlight = NSBezierPath(roundedRect: square.insetBy(dx: 9, dy: 9), xRadius: 14, yRadius: 14)
                    highlight.lineWidth = 7
                    highlight.stroke()
                }
            }
        }
    }

    private static func petColaIcon() -> NSImage {
        makeIcon {
            let canRect = NSRect(x: 134, y: 48, width: 244, height: 416)
            NSColor(calibratedRed: 0.84, green: 0.08, blue: 0.10, alpha: 1).setFill()
            NSBezierPath(roundedRect: canRect, xRadius: 54, yRadius: 54).fill()

            NSColor(calibratedWhite: 0.90, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 134, y: 408, width: 244, height: 70)).fill()
            NSBezierPath(ovalIn: NSRect(x: 134, y: 34, width: 244, height: 70)).fill()

            NSColor.white.setFill()
            NSColor.white.setStroke()
            let wave = NSBezierPath()
            wave.move(to: NSPoint(x: 154, y: 190))
            wave.curve(
                to: NSPoint(x: 358, y: 320),
                controlPoint1: NSPoint(x: 210, y: 300),
                controlPoint2: NSPoint(x: 296, y: 204)
            )
            wave.lineWidth = 34
            wave.lineCapStyle = .round
            wave.stroke()

            for bubble in [
                NSRect(x: 190, y: 328, width: 34, height: 34),
                NSRect(x: 275, y: 350, width: 24, height: 24),
                NSRect(x: 310, y: 145, width: 30, height: 30)
            ] {
                NSBezierPath(ovalIn: bubble).fill()
            }
        }
    }
}
