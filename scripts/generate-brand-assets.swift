#!/usr/bin/env swift
import AppKit

// Run from the repository root. Keep the logo geometry aligned with LessBarMark.
let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let brand = root.appendingPathComponent("Resources/Brand")
let preview = root.appendingPathComponent("output/brand")
let iconset = root.appendingPathComponent(".build/LessBar.iconset")
for directory in [brand, preview, iconset] {
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
}
let ink = NSColor(srgbRed: 0.09, green: 0.10, blue: 0.12, alpha: 1)
let muted = NSColor(srgbRed: 0.42, green: 0.44, blue: 0.47, alpha: 1)

func mark(_ frame: NSRect, color: NSColor) {
    let s = min(frame.width / 256, frame.height / 128)
    let x = frame.midX - 128 * s
    let y = frame.midY - 64 * s
    color.setFill()
    NSBezierPath(roundedRect: NSRect(x: x + 20*s, y: y + 40*s, width: 144*s, height: 48*s),
                 xRadius: 24*s, yRadius: 24*s).fill()
    NSBezierPath(ovalIn: NSRect(x: x + 188*s, y: y + 40*s, width: 48*s, height: 48*s)).fill()
}

func appIcon(_ frame: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    let transform = AffineTransform(translationByX: frame.minX, byY: frame.minY)
    (transform as NSAffineTransform).concat()
    let scale = NSAffineTransform()
    scale.scaleX(by: frame.width / 1024, yBy: frame.height / 1024)
    scale.concat()
    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928),
                 xRadius: 210, yRadius: 210).fill()
    mark(NSRect(x: 112, y: 312, width: 800, height: 400), color: .white)
    NSGraphicsContext.restoreGraphicsState()
}

func png(width: Int, height: Int, to url: URL, draw: () -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill(using: .copy)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat,
           weight: NSFont.Weight = .regular, color: NSColor = ink) {
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
    ])
}

let shapes = "<rect x=\"20\" y=\"40\" width=\"144\" height=\"48\" rx=\"24\"/><circle cx=\"212\" cy=\"64\" r=\"24\"/>"
for (filename, color) in [("lessbar-mark.svg", "#171a1f"), ("lessbar-mark-white.svg", "#ffffff")] {
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 128" role="img" aria-label="Less Bar">
      <title>Less Bar — LESS mark</title>
      <g fill="\(color)">\(shapes)</g>
    </svg>
    """
    try svg.write(to: brand.appendingPathComponent(filename), atomically: true, encoding: .utf8)
}
let iconSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="Less Bar app icon">
  <title>Less Bar app icon</title>
  <rect x="48" y="48" width="928" height="928" rx="210" fill="#171a1f"/>
  <g transform="translate(112 312) scale(3.125)" fill="#fff">\(shapes)</g>
</svg>
"""
try iconSVG.write(to: brand.appendingPathComponent("lessbar-app-icon.svg"), atomically: true, encoding: .utf8)

final class MarkView: NSView {
    override func draw(_ dirtyRect: NSRect) { mark(bounds, color: ink) }
}
let view = MarkView(frame: NSRect(x: 0, y: 0, width: 256, height: 128))
try view.dataWithPDF(inside: view.bounds).write(to: brand.appendingPathComponent("LessBarMark.pdf"))

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = points * factor
        let suffix = factor == 2 ? "@2x" : ""
        try png(width: pixels, height: pixels,
                to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")) {
            appIcon(NSRect(x: 0, y: 0, width: pixels, height: pixels))
        }
    }
}
let iconPNG = brand.appendingPathComponent("lessbar-app-icon-1024.png")
try png(width: 1024, height: 1024, to: iconPNG) {
    appIcon(NSRect(x: 0, y: 0, width: 1024, height: 1024))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }

try png(width: 1440, height: 920, to: preview.appendingPathComponent("lessbar-brand-preview.png")) {
    NSColor(srgbRed: 0.975, green: 0.975, blue: 0.965, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 1440, height: 920).fill()
    label("Less Bar", x: 80, y: 785, size: 66, weight: .bold)
    label("A little less. A lot clearer.", x: 82, y: 748, size: 24, color: muted)
    mark(NSRect(x: 72, y: 400, width: 580, height: 290), color: ink)
    label("LESS / Primary mark", x: 82, y: 390, size: 20, weight: .medium)
    appIcon(NSRect(x: 945, y: 414, width: 270, height: 270))
    label("App icon", x: 1036, y: 390, size: 20, weight: .medium)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 80, y: 120, width: 605, height: 215), xRadius: 24, yRadius: 24).fill()
    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: 715, y: 120, width: 645, height: 215), xRadius: 24, yRadius: 24).fill()
    mark(NSRect(x: 110, y: 172, width: 144, height: 72), color: ink)
    label("Less Bar", x: 276, y: 184, size: 40, weight: .semibold)
    mark(NSRect(x: 748, y: 172, width: 144, height: 72), color: .white)
    label("Less Bar", x: 914, y: 184, size: 40, weight: .semibold, color: .white)
    label("SMALL SIZES", x: 82, y: 58, size: 13, weight: .medium, color: muted)
    for (index, size) in [16, 24, 32, 48].enumerated() {
        appIcon(NSRect(x: 215 + index * 80, y: 42, width: size, height: size))
    }
    label("Monochrome / Vector master / 2026", x: 1020, y: 58, size: 15, color: muted)
}
print("Generated Less Bar SVG, PDF, PNG, ICNS and brand preview.")
