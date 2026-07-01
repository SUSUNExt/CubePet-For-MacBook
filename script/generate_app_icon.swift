import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift <output.png>\n", stderr)
    exit(2)
}

let pixelSize = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: [],
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("failed to create icon bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

let bodyRect = NSRect(x: 142, y: 142, width: 740, height: 740)
let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 126, yRadius: 126)

let bodyShadow = NSShadow()
bodyShadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
bodyShadow.shadowBlurRadius = 46
bodyShadow.shadowOffset = NSSize(width: 0, height: -22)
bodyShadow.set()
NSColor.black.setFill()
bodyPath.fill()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

NSColor(white: 0.20, alpha: 1).setStroke()
bodyPath.lineWidth = 6
bodyPath.stroke()

let eyeShadow = NSShadow()
eyeShadow.shadowColor = NSColor.white.withAlphaComponent(0.92)
eyeShadow.shadowBlurRadius = 34
eyeShadow.shadowOffset = .zero
eyeShadow.set()

NSColor.white.setFill()
let leftEye = NSBezierPath(roundedRect: NSRect(x: 326, y: 454, width: 118, height: 176), xRadius: 59, yRadius: 59)
let rightEye = NSBezierPath(roundedRect: NSRect(x: 580, y: 454, width: 118, height: 176), xRadius: 59, yRadius: 59)
leftEye.fill()
rightEye.fill()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to encode icon PNG\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
