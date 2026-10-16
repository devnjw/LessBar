import AppKit
import XCTest
@testable import LessBar

final class ChevronAppearanceTests: XCTestCase {
    @MainActor func testEditingDividerKeepsWhitePixelsAcrossAppearancesAndDisplayScales() throws {
        let button = NSButton()
        button.font = NSFont.menuBarFont(ofSize: 0)
        button.title = "│"
        ChevronAppearance.configureDivider(button)
        XCTAssertEqual(button.title, "", "No native text should remain for AppKit to recolor")
        let image = try XCTUnwrap(button.image)
        XCTAssertFalse(image.isTemplate)
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            for scale in [1, 2] {
                var bitmap: NSBitmapImageRep?
                var error: Error?
                appearance.performAsCurrentDrawingAppearance {
                    do { bitmap = try render(image, scale: scale) }
                    catch let caught { error = caught }
                }
                if let error { throw error }
                let rendered = try XCTUnwrap(bitmap)
                var paintedPixels = 0
                for y in 0..<rendered.pixelsHigh {
                    for x in 0..<rendered.pixelsWide {
                        let color = try XCTUnwrap(rendered.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                        if color.alphaComponent > 0.1 {
                            paintedPixels += 1
                            XCTAssertGreaterThanOrEqual(color.redComponent, 0.99)
                            XCTAssertGreaterThanOrEqual(color.greenComponent, 0.99)
                            XCTAssertGreaterThanOrEqual(color.blueComponent, 0.99)
                        }
                    }
                }
                XCTAssertGreaterThan(paintedPixels, 0)
            }
        }
        ChevronAppearance.configure(button, collapsed: false)
        XCTAssertTrue(button.image === ChevronAppearance.image(collapsed: false))
        XCTAssertEqual(button.title, "")
    }

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
