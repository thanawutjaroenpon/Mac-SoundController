import AppKit

// Draws the app icon (mixer sliders on a gradient squircle) into an .iconset folder.
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.05
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.225, yRadius: s * 0.225)
    NSGradient(colors: [NSColor(red: 0.42, green: 0.25, blue: 0.95, alpha: 1),
                        NSColor(red: 0.98, green: 0.35, blue: 0.55, alpha: 1)])!.draw(in: bg, angle: -60)

    let levels: [CGFloat] = [0.45, 0.8, 0.6]
    let trackW = s * 0.07, top = s * 0.74, bottom = s * 0.26
    for (i, lv) in levels.enumerated() {
        let x = s * (0.3 + 0.2 * CGFloat(i))
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: NSRect(x: x - trackW / 2, y: bottom, width: trackW, height: top - bottom),
                     xRadius: trackW / 2, yRadius: trackW / 2).fill()
        let ky = bottom + (top - bottom) * lv
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: x - trackW / 2, y: bottom, width: trackW, height: ky - bottom),
                     xRadius: trackW / 2, yRadius: trackW / 2).fill()
        let kr = s * 0.062
        NSColor.white.setFill()
        let knob = NSBezierPath(ovalIn: NSRect(x: x - kr, y: ky - kr, width: 2 * kr, height: 2 * kr))
        NSShadow().apply(radius: s * 0.015, dy: -s * 0.008) { knob.fill() }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

extension NSShadow {
    func apply(radius: CGFloat, dy: CGFloat, _ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        shadowBlurRadius = radius; shadowOffset = NSSize(width: 0, height: dy)
        shadowColor = NSColor.black.withAlphaComponent(0.35); set()
        body()
        NSGraphicsContext.restoreGraphicsState()
    }
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
