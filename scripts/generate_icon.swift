import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("build/Msgbox.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let symbol = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 600, weight: .regular))!
let glyph = NSImage(size: symbol.size)
glyph.lockFocus()
symbol.draw(at: .zero, from: .zero, operation: .copy, fraction: 1)
NSColor.white.setFill()
NSRect(origin: .zero, size: symbol.size).fill(using: .sourceIn)
glyph.unlockFocus()

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor.systemIndigo.setFill()
        NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200).fill()
        let width: CGFloat = 640
        let height = width * glyph.size.height / glyph.size.width
        glyph.draw(in: NSRect(x: (1024 - width) / 2, y: (1024 - height) / 2, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        let png = bitmap.representation(using: .png, properties: [:])!
        assert(NSBitmapImageRep(data: png)!.pixelsWide == pixels)
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try png.write(to: iconset.appendingPathComponent(name))
        if pixels == 1024 { try png.write(to: root.appendingPathComponent("docs/app-icon.png")) }
    }
}
let output = root.appendingPathComponent("Msgbox/AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
assert(process.terminationStatus == 0)
let data = try Data(contentsOf: output)
assert(data.prefix(4) == Data("icns".utf8))
print("Generated AppIcon.icns from the menu-bar SF Symbol; all icon sizes verified.")
