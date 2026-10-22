import AppKit

/// Draws the NoteCraft app icon on a 1024 × 1024 canvas following the macOS icon grid.
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = size / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let outerShadow = NSShadow()
    outerShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    outerShadow.shadowBlurRadius = 24
    outerShadow.shadowOffset = NSSize(width: 0, height: -10)
    outerShadow.set()
    NSColor(srgbRed: 0.95, green: 0.33, blue: 0.36, alpha: 1).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()

    let background = NSGradient(colors: [
        NSColor(srgbRed: 1.00, green: 0.56, blue: 0.36, alpha: 1),
        NSColor(srgbRed: 0.93, green: 0.30, blue: 0.40, alpha: 1)
    ])
    background?.draw(in: body, angle: -90)

    let highlight = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    highlight.lineWidth = 4
    highlight.stroke()

    let pageRect = NSRect(x: 292, y: 218, width: 440, height: 588)
    let fold: CGFloat = 116
    let page = NSBezierPath()
    page.move(to: NSPoint(x: pageRect.minX + 40, y: pageRect.minY))
    page.line(to: NSPoint(x: pageRect.maxX - 40, y: pageRect.minY))
    page.curve(to: NSPoint(x: pageRect.maxX, y: pageRect.minY + 40), controlPoint1: NSPoint(x: pageRect.maxX - 18, y: pageRect.minY), controlPoint2: NSPoint(x: pageRect.maxX, y: pageRect.minY + 18))
    page.line(to: NSPoint(x: pageRect.maxX, y: pageRect.maxY - fold))
    page.line(to: NSPoint(x: pageRect.maxX - fold, y: pageRect.maxY))
    page.line(to: NSPoint(x: pageRect.minX + 40, y: pageRect.maxY))
    page.curve(to: NSPoint(x: pageRect.minX, y: pageRect.maxY - 40), controlPoint1: NSPoint(x: pageRect.minX + 18, y: pageRect.maxY), controlPoint2: NSPoint(x: pageRect.minX, y: pageRect.maxY - 18))
    page.line(to: NSPoint(x: pageRect.minX, y: pageRect.minY + 40))
    page.curve(to: NSPoint(x: pageRect.minX + 40, y: pageRect.minY), controlPoint1: NSPoint(x: pageRect.minX, y: pageRect.minY + 18), controlPoint2: NSPoint(x: pageRect.minX + 18, y: pageRect.minY))
    page.close()

    NSGraphicsContext.saveGraphicsState()
    let pageShadow = NSShadow()
    pageShadow.shadowColor = NSColor(srgbRed: 0.45, green: 0.08, blue: 0.12, alpha: 0.35)
    pageShadow.shadowBlurRadius = 30
    pageShadow.shadowOffset = NSSize(width: 0, height: -14)
    pageShadow.set()
    NSColor(srgbRed: 0.99, green: 0.98, blue: 0.96, alpha: 1).setFill()
    page.fill()
    NSGraphicsContext.restoreGraphicsState()

    let corner = NSBezierPath()
    corner.move(to: NSPoint(x: pageRect.maxX - fold, y: pageRect.maxY))
    corner.line(to: NSPoint(x: pageRect.maxX - fold, y: pageRect.maxY - fold + 18))
    corner.curve(to: NSPoint(x: pageRect.maxX - fold + 18, y: pageRect.maxY - fold), controlPoint1: NSPoint(x: pageRect.maxX - fold, y: pageRect.maxY - fold + 6), controlPoint2: NSPoint(x: pageRect.maxX - fold + 6, y: pageRect.maxY - fold))
    corner.line(to: NSPoint(x: pageRect.maxX, y: pageRect.maxY - fold))
    corner.close()
    NSColor(srgbRed: 0.90, green: 0.86, blue: 0.82, alpha: 1).setFill()
    corner.fill()

    let ink = NSColor(srgbRed: 0.17, green: 0.18, blue: 0.27, alpha: 1)
    let lines: [(x: CGFloat, width: CGFloat, color: NSColor)] = [
        (350, 232, ink.withAlphaComponent(0.85)),
        (350, 300, NSColor(srgbRed: 0.95, green: 0.38, blue: 0.36, alpha: 1)),
        (402, 222, NSColor(srgbRed: 0.16, green: 0.56, blue: 0.62, alpha: 1)),
        (402, 174, ink.withAlphaComponent(0.45)),
        (350, 132, ink.withAlphaComponent(0.85))
    ]
    var y: CGFloat = 640
    for line in lines {
        let bar = NSBezierPath(roundedRect: NSRect(x: line.x, y: y, width: line.width, height: 30), xRadius: 15, yRadius: 15)
        line.color.setFill()
        bar.fill()
        y -= 78
    }
    let caret = NSBezierPath(roundedRect: NSRect(x: 350 + 132 + 26, y: y + 78 - 14, width: 14, height: 58), xRadius: 7, yRadius: 7)
    NSColor(srgbRed: 0.95, green: 0.38, blue: 0.36, alpha: 1).setFill()
    caret.fill()

    image.unlockFocus()
    return image
}

/// Writes `image` as PNG with exactly `pixels` × `pixels` pixels.
func writePNG(_ image: NSImage, pixels: Int, to url: URL) throws {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    representation.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try representation.representation(using: .png, properties: [:])?.write(to: url)
}

let outputFolder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "NoteCraft/Resources/Assets.xcassets/AppIcon.appiconset")
let variants: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [String] = []
for variant in variants {
    let pixels = variant.points * variant.scale
    let name = "icon_\(variant.points)x\(variant.points)\(variant.scale == 2 ? "@2x" : "").png"
    try writePNG(drawIcon(size: CGFloat(pixels)), pixels: pixels, to: outputFolder.appendingPathComponent(name))
    images.append("""
        { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(variant.scale)x", "size" : "\(variant.points)x\(variant.points)" }
    """)
}
let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

"""
try contents.write(to: outputFolder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Wrote \(variants.count) icon images to \(outputFolder.path)")
