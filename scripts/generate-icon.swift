import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ScrcpyMenu.iconset"
let variant = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "release"

let gradientColors: [NSColor]
if variant == "dev" {
    gradientColors = [
        NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.85, green: 0.38, blue: 0.05, alpha: 1),
    ]
} else {
    gradientColors = [
        NSColor(calibratedRed: 0.24, green: 0.58, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.34, blue: 0.85, alpha: 1),
    ]
}

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

func render(pixels: Int) -> Data? {
    let s = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
        let inset = s * 0.06
        let iconRect = rect.insetBy(dx: inset, dy: inset)
        let radius = iconRect.width * 0.225
        let path = NSBezierPath(roundedRect: iconRect, xRadius: radius, yRadius: radius)
        let gradient = NSGradient(colors: gradientColors)!
        gradient.draw(in: path, angle: -90)

        let config = NSImage.SymbolConfiguration(pointSize: iconRect.width * 0.52, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: "iphone", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return false }
        let symSize = symbol.size
        let tinted = NSImage(size: symSize, flipped: false) { tintRect in
            symbol.draw(in: tintRect, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor.white.set()
            tintRect.fill(using: .sourceIn)
            return true
        }
        let symRect = NSRect(
            x: rect.midX - symSize.width / 2,
            y: rect.midY - symSize.height / 2,
            width: symSize.width,
            height: symSize.height
        )
        tinted.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1)
        return true
    }
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
for entry in entries {
    guard let png = render(pixels: entry.pixels) else {
        FileHandle.standardError.write("failed to render \(entry.name)\n".data(using: .utf8)!)
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: outputDir + "/" + entry.name + ".png"))
    print("wrote \(entry.name).png (\(entry.pixels)px)")
}
