import CoreGraphics
import Foundation
import ImageIO

struct ScreenshotSampleRegion: Sendable, Equatable {
    let xFraction: Double
    let yFraction: Double
    let widthFraction: Double
    let heightFraction: Double

    static let fullFrame = ScreenshotSampleRegion(
        xFraction: 0,
        yFraction: 0,
        widthFraction: 1,
        heightFraction: 1
    )

    // Keeps analysis away from top-bar clock/cursor and display edges.
    static let stableCanvas = ScreenshotSampleRegion(
        xFraction: 0.05,
        yFraction: 0.12,
        widthFraction: 0.90,
        heightFraction: 0.82
    )
}

struct ScreenshotDiffMetrics: Sendable, Equatable {
    let sampledPixelCount: Int
    let changedPixelCount: Int
    let changedPixelRatio: Double
    let maxChannelDelta: Int
}

struct ScreenshotVisualStats: Sendable, Equatable {
    let sampledPixelCount: Int
    let quantizedColorCount: Int
    let luminanceStdDev: Double
}

enum ScreenshotMetrics {
    static func diff(
        baselineURL: URL,
        candidateURL: URL,
        region: ScreenshotSampleRegion,
        perChannelTolerance: Int = 2,
        sampleStride: Int = 1
    ) throws -> ScreenshotDiffMetrics {
        let baseline = try loadRGBA8Image(url: baselineURL)
        let candidate = try loadRGBA8Image(url: candidateURL)
        let width = min(baseline.width, candidate.width)
        let height = min(baseline.height, candidate.height)
        let sampleRect = normalizedPixelRect(
            width: width,
            height: height,
            region: region
        )

        var sampledPixelCount = 0
        var changedPixelCount = 0
        var maxChannelDelta = 0
        let rowStride = max(1, sampleStride)
        let columnStride = max(1, sampleStride)

        for y in stride(from: sampleRect.minY, to: sampleRect.maxY, by: rowStride) {
            for x in stride(from: sampleRect.minX, to: sampleRect.maxX, by: columnStride) {
                let baselineOffset = ((y * baseline.width) + x) * 4
                let candidateOffset = ((y * candidate.width) + x) * 4
                let deltaR = abs(Int(baseline.pixels[baselineOffset]) - Int(candidate.pixels[candidateOffset]))
                let deltaG = abs(Int(baseline.pixels[baselineOffset + 1]) - Int(candidate.pixels[candidateOffset + 1]))
                let deltaB = abs(Int(baseline.pixels[baselineOffset + 2]) - Int(candidate.pixels[candidateOffset + 2]))
                let localMaxDelta = max(deltaR, max(deltaG, deltaB))
                maxChannelDelta = max(maxChannelDelta, localMaxDelta)
                if localMaxDelta > perChannelTolerance {
                    changedPixelCount += 1
                }
                sampledPixelCount += 1
            }
        }

        let changedPixelRatio: Double
        if sampledPixelCount == 0 {
            changedPixelRatio = 0
        } else {
            changedPixelRatio = Double(changedPixelCount) / Double(sampledPixelCount)
        }
        return ScreenshotDiffMetrics(
            sampledPixelCount: sampledPixelCount,
            changedPixelCount: changedPixelCount,
            changedPixelRatio: changedPixelRatio,
            maxChannelDelta: maxChannelDelta
        )
    }

    static func visualStats(
        imageURL: URL,
        region: ScreenshotSampleRegion,
        sampleStride: Int = 2,
        quantizationStep: Int = 32
    ) throws -> ScreenshotVisualStats {
        let image = try loadRGBA8Image(url: imageURL)
        let sampleRect = normalizedPixelRect(
            width: image.width,
            height: image.height,
            region: region
        )
        let sampleStep = max(1, sampleStride)
        let quantization = max(1, quantizationStep)

        var sampledPixelCount = 0
        var luminanceMean = 0.0
        var luminanceM2 = 0.0
        var quantizedColors = Set<UInt32>()

        for y in stride(from: sampleRect.minY, to: sampleRect.maxY, by: sampleStep) {
            for x in stride(from: sampleRect.minX, to: sampleRect.maxX, by: sampleStep) {
                let offset = ((y * image.width) + x) * 4
                let r = Int(image.pixels[offset])
                let g = Int(image.pixels[offset + 1])
                let b = Int(image.pixels[offset + 2])
                let luminance = (0.2126 * Double(r)) + (0.7152 * Double(g)) + (0.0722 * Double(b))
                sampledPixelCount += 1
                let delta = luminance - luminanceMean
                luminanceMean += delta / Double(sampledPixelCount)
                let delta2 = luminance - luminanceMean
                luminanceM2 += delta * delta2

                let qr = UInt32((r / quantization) * quantization)
                let qg = UInt32((g / quantization) * quantization)
                let qb = UInt32((b / quantization) * quantization)
                let key = (qr << 16) | (qg << 8) | qb
                quantizedColors.insert(key)
            }
        }

        let luminanceVariance: Double
        if sampledPixelCount < 2 {
            luminanceVariance = 0
        } else {
            luminanceVariance = luminanceM2 / Double(sampledPixelCount - 1)
        }
        return ScreenshotVisualStats(
            sampledPixelCount: sampledPixelCount,
            quantizedColorCount: quantizedColors.count,
            luminanceStdDev: sqrt(max(0, luminanceVariance))
        )
    }

    private static func normalizedPixelRect(
        width: Int,
        height: Int,
        region: ScreenshotSampleRegion
    ) -> (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        let clampedX = min(max(0, region.xFraction), 1)
        let clampedY = min(max(0, region.yFraction), 1)
        let clampedWidth = min(max(0, region.widthFraction), 1)
        let clampedHeight = min(max(0, region.heightFraction), 1)

        let minX = min(max(0, Int(floor(clampedX * Double(width)))), max(0, width - 1))
        let minY = min(max(0, Int(floor(clampedY * Double(height)))), max(0, height - 1))
        let maxX = min(width, max(minX + 1, Int(ceil((clampedX + clampedWidth) * Double(width)))))
        let maxY = min(height, max(minY + 1, Int(ceil((clampedY + clampedHeight) * Double(height)))))
        return (minX, minY, maxX, maxY)
    }

    private static func loadRGBA8Image(url: URL) throws -> RGBA8Image {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScreenshotMetricsError.decodeFailed(url)
        }

        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        let contextCreated = pixels.withUnsafeMutableBytes { rawPixels in
            guard let baseAddress = rawPixels.baseAddress else {
                return false
            }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard contextCreated else {
            throw ScreenshotMetricsError.rasterizationFailed(url)
        }
        return RGBA8Image(width: width, height: height, pixels: pixels)
    }
}

private struct RGBA8Image: Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]
}

private enum ScreenshotMetricsError: Error {
    case decodeFailed(URL)
    case rasterizationFailed(URL)
}
