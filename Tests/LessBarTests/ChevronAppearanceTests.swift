import AppKit
import XCTest
@testable import LessBar

final class ChevronAppearanceTests: XCTestCase {
    @MainActor func testDirectionsHaveIdenticalMirroredPixelsAtBothDisplayScales() throws {
        let right = try XCTUnwrap(ChevronAppearance.image(collapsed: false))
        let left = try XCTUnwrap(ChevronAppearance.image(collapsed: true))
        for scale in [1, 2] {
            let expanded = try render(right, scale: scale)
            let collapsed = try render(left, scale: scale)
            var largestDifference: CGFloat = 0
            var paintedPixels = 0
            for y in 0..<expanded.pixelsHigh {
                for x in 0..<expanded.pixelsWide {
                    let a = try XCTUnwrap(expanded.colorAt(x: x, y: y))
                    let b = try XCTUnwrap(collapsed.colorAt(x: expanded.pixelsWide - 1 - x, y: y))
                    largestDifference = max(largestDifference, abs(a.alphaComponent - b.alphaComponent))
                    if a.alphaComponent > 0.1 { paintedPixels += 1 }
                }
            }
            XCTAssertGreaterThan(paintedPixels, 0)
            XCTAssertLessThanOrEqual(largestDifference, 1.0 / 255, "Scale \(scale)x")
        }
    }

    @MainActor private func render(_ image: NSImage, scale: Int) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(image.size.width) * scale, pixelsHigh: Int(image.size.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(scale))
        transform.concat()
        image.draw(in: NSRect(origin: .zero, size: image.size))
        return bitmap
    }
}
