// Draws the app icon: a sticky note tucked into a folder, flat, on warm paper.
// Run: swift scripts/make_icon.swift  (writes App/Assets.xcassets/AppIcon.appiconset and docs/images/icon.png)
import AppKit

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func draw(size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: s, y: s)

    // Standard macOS icon body: 824 × 824 rounded square, centred.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.22))
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil))
    ctx.setFillColor(color(0xF4EFE6))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil))
    ctx.clip()

    // Folder back with tab.
    let back = CGMutablePath()
    back.addRoundedRect(in: CGRect(x: 214, y: 236, width: 596, height: 420), cornerWidth: 34, cornerHeight: 34)
    back.addRoundedRect(in: CGRect(x: 214, y: 600, width: 236, height: 96), cornerWidth: 30, cornerHeight: 30)
    ctx.addPath(back)
    ctx.setFillColor(color(0x5F7FA8))
    ctx.fillPath()

    // Sticky note, tilted, sticking out of the folder.
    ctx.saveGState()
    ctx.translateBy(x: 540, y: 560)
    ctx.rotate(by: -0.10)
    let note = CGRect(x: -170, y: -150, width: 340, height: 330)
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: CGColor(gray: 0, alpha: 0.15))
    ctx.addPath(CGPath(roundedRect: note, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(color(0xF2D985))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setFillColor(color(0xC9A84A))
    for (i, w) in [CGFloat(220), 250, 170].enumerated() {
        ctx.addPath(CGPath(roundedRect: CGRect(x: -130, y: 110 - CGFloat(i) * 52, width: w, height: 20), cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // Folder front.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 14, color: CGColor(gray: 0, alpha: 0.12))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 214, y: 236, width: 596, height: 300), cornerWidth: 34, cornerHeight: 34, transform: nil))
    ctx.setFillColor(color(0x7C9CC4))
    ctx.fillPath()
    ctx.restoreGState()

    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let set = root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
var images: [[String: String]] = []
for pt in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = pt * scale
        let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
        try draw(size: px).write(to: set.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(pt)x\(pt)", "scale": "\(scale)x", "filename": name])
    }
}
let json = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted])
try json.write(to: set.appendingPathComponent("Contents.json"))
let docs = root.appendingPathComponent("docs/images")
try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
try draw(size: 512).write(to: docs.appendingPathComponent("icon.png"))
print("icon written")
