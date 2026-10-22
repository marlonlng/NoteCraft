import AppKit

struct Slide {
    let file: String
    let headline: String
    let subline: String
}

let slides = [
    Slide(file: "01-Editor", headline: "Schnell. Nativ. Für den Mac.", subline: "Syntaxhervorhebung für über 30 Sprachen – ohne Ballast."),
    Slide(file: "02-Suchen", headline: "Suchen wie ein Profi", subline: "Reguläre Ausdrücke, Trefferzähler und Ersetzen in einem Schritt."),
    Slide(file: "03-Befehlspalette", headline: "Jeder Befehl in Reichweite", subline: "Die Befehlspalette (⇧⌘A) findet alles – auch Textumwandlungen."),
    Slide(file: "04-Markdown", headline: "Notizen, Code und Daten", subline: "Markdown, JSON, YAML und mehr – hell oder dunkel."),
    Slide(file: "05-Farbschema", headline: "Passt sich dir an", subline: "Farbschemata folgen automatisch dem Erscheinungsbild des Systems.")
]

/// Draws one App Store slide of 2880 × 1800 pixels with headline, subline and the window screenshot.
func compose(_ slide: Slide, screenshot: NSImage) -> NSBitmapImageRep? {
    let width = 2880
    let height = 1800
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    representation.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    let canvas = NSRect(x: 0, y: 0, width: width, height: height)
    NSGradient(colors: [
        NSColor(srgbRed: 1.00, green: 0.56, blue: 0.36, alpha: 1),
        NSColor(srgbRed: 0.88, green: 0.27, blue: 0.40, alpha: 1)
    ])?.draw(in: canvas, angle: -90)

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let headline = NSAttributedString(string: slide.headline, attributes: [
        .font: NSFont.systemFont(ofSize: 120, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ])
    headline.draw(in: NSRect(x: 0, y: 1520, width: width, height: 170))
    let subline = NSAttributedString(string: slide.subline, attributes: [
        .font: NSFont.systemFont(ofSize: 60, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.9),
        .paragraphStyle: paragraph
    ])
    subline.draw(in: NSRect(x: 0, y: 1420, width: width, height: 90))

    let available = NSSize(width: 2400, height: 1300)
    let scale = min(available.width / screenshot.size.width, available.height / screenshot.size.height)
    let size = NSSize(width: screenshot.size.width * scale, height: screenshot.size.height * scale)
    let frame = NSRect(x: (CGFloat(width) - size.width) / 2, y: 60 + (available.height - size.height) / 2, width: size.width, height: size.height)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let clip = NSBezierPath(roundedRect: frame, xRadius: 28, yRadius: 28)
    NSColor.black.setFill()
    clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    screenshot.draw(in: frame)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return representation
}

let arguments = CommandLine.arguments
let inputFolder = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "build/screenshots")
let outputFolder = URL(fileURLWithPath: arguments.count > 2 ? arguments[2] : "AppStore/Screenshots/de-DE")
try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
for slide in slides {
    let input = inputFolder.appendingPathComponent(slide.file + ".png")
    guard let screenshot = NSImage(contentsOf: input), let image = compose(slide, screenshot: screenshot),
          let data = image.representation(using: .png, properties: [:]) else {
        print("Skipped \(slide.file)")
        continue
    }
    try data.write(to: outputFolder.appendingPathComponent(slide.file + ".png"))
    print("Wrote \(slide.file).png")
}
