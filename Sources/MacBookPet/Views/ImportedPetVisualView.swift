import AppKit
import ImageIO
import SwiftUI

struct ImportedPetVisualView: View {
    let asset: PetImportedVisualAsset?
    let baseOffset: NormalizedVisualOffset?
    let animationPlaybackRate: Double?
    var playsAnimation = true
    let configuration: PetEyeModuleConfiguration?
    let expression: PetExpression
    let isBlinking: Bool
    let gazeOffset: CGSize
    var customEyeAsset: PetImportedVisualAsset? = nil
    var showsMissingAssetIcon = true
    var appliesVerticalBaseOffsetInView = true

    var body: some View {
        ZStack {
            Group {
                if let asset {
                    AnimatedPetImageView(
                        asset: asset,
                        playbackRate: animationPlaybackRate ?? 1,
                        playsAnimation: playsAnimation
                    )
                } else if showsMissingAssetIcon {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
            .offset(renderedBaseOffset)

            if let configuration {
                TrackingEyesView(
                    configuration: configuration,
                    expression: expression,
                    isBlinking: isBlinking,
                    gazeOffset: gazeOffset,
                    customEyeAsset: customEyeAsset
                )
            }
        }
    }

    private var renderedBaseOffset: CGSize {
        let offset = baseOffset ?? .zero
        return CGSize(
            width: CGFloat(offset.x) * PetMetrics.bodyContentSize,
            height: appliesVerticalBaseOffsetInView
                ? CGFloat(offset.y) * PetMetrics.bodyContentSize
                : 0
        )
    }
}

private struct AnimatedPetImageView: View {
    let asset: PetImportedVisualAsset
    let playbackRate: Double
    let playsAnimation: Bool

    var body: some View {
        if asset.isAnimated && playsAnimation {
            TimelineView(.animation) { timeline in
                if let image = image(at: timeline.date) {
                    rendered(image)
                }
            }
        } else if let image = firstImage {
            rendered(image)
        }
    }

    private var firstImage: NSImage? {
        switch asset.kind {
        case .gif:
            return GIFFrameCache.animation(for: asset.imageURL)?.firstImage
        case .stillImage, .frameAnimation:
            return PetImportedImageCache.image(for: asset.imageURL)
        }
    }

    private func rendered(_ image: NSImage) -> some View {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
    }

    private func image(at date: Date) -> NSImage? {
        switch asset.kind {
        case .stillImage:
            return PetImportedImageCache.image(for: asset.imageURL)
        case .gif:
            return GIFFrameCache.animation(for: asset.imageURL)?.image(
                at: date,
                playbackRate: playbackRate
            )
        case .frameAnimation:
            guard !asset.frameURLs.isEmpty else { return nil }
            let elapsed = date.timeIntervalSinceReferenceDate * playbackRate
            let index = Int(elapsed / 0.1).quotientAndRemainder(dividingBy: asset.frameURLs.count).remainder
            return PetImportedImageCache.image(for: asset.frameURLs[index])
        }
    }
}

private final class GIFFrameAnimation {
    private let frames: [NSImage]
    private let delays: [TimeInterval]
    private let duration: TimeInterval
    let memoryCost: Int

    init?(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [NSImage] = []
        var delays: [TimeInterval] = []
        var memoryCost = 0
        for index in 0 ..< count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(NSImage(cgImage: image, size: .zero))
            delays.append(Self.delay(for: source, index: index))
            memoryCost += image.width * image.height * 4
        }
        guard !frames.isEmpty else { return nil }
        self.frames = frames
        self.delays = delays
        duration = delays.reduce(0, +)
        self.memoryCost = max(memoryCost, 1)
    }

    func image(at date: Date, playbackRate: Double) -> NSImage {
        let elapsed = (date.timeIntervalSinceReferenceDate * playbackRate)
            .truncatingRemainder(dividingBy: duration)
        var cursor: TimeInterval = 0
        for (index, delay) in delays.enumerated() {
            cursor += delay
            if elapsed < cursor { return frames[index] }
        }
        return frames[frames.count - 1]
    }

    var firstImage: NSImage? {
        frames.first
    }

    private static func delay(for source: CGImageSource, index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let unclampedDelay = gifProperties?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let delay = unclampedDelay ?? (gifProperties?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
        return max(delay, 0.02)
    }
}

private enum GIFFrameCache {
    private static let animations: NSCache<NSURL, GIFFrameAnimation> = {
        let cache = NSCache<NSURL, GIFFrameAnimation>()
        cache.countLimit = 4
        cache.totalCostLimit = 128 * 1_024 * 1_024
        return cache
    }()

    static func animation(for url: URL) -> GIFFrameAnimation? {
        let key = url as NSURL
        if let animation = animations.object(forKey: key) { return animation }
        guard let animation = GIFFrameAnimation(url: url) else { return nil }
        animations.setObject(animation, forKey: key, cost: animation.memoryCost)
        return animation
    }
}
