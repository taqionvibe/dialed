// Renders Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }
    let s = size / 1024
    let rect = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)

    // Squircle body with a deep graphite gradient.
    let body = NSBezierPath(roundedRect: rect, xRadius: 185 * s, yRadius: 185 * s)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 30 * s, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1).setFill()
    body.fill()
    ctx.restoreGState()
    body.addClip()
    NSGradient(colors: [NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.24, alpha: 1),
                        NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1)])!
        .draw(in: body, angle: -90)

    let center = CGPoint(x: 512 * s, y: 512 * s)

    // Tick marks around the dial (16 steps, like the buds' volume grid).
    for i in 0..<16 {
        let a = CGFloat(i) / 16 * 2 * .pi + .pi / 2
        let inner: CGFloat = 330 * s, outer: CGFloat = (i % 4 == 0 ? 372 : 358) * s
        let p = NSBezierPath()
        p.move(to: CGPoint(x: center.x + cos(a) * inner, y: center.y + sin(a) * inner))
        p.line(to: CGPoint(x: center.x + cos(a) * outer, y: center.y + sin(a) * outer))
        p.lineWidth = (i % 4 == 0 ? 14 : 9) * s
        p.lineCapStyle = .round
        NSColor.white.withAlphaComponent(i % 4 == 0 ? 0.55 : 0.28).setStroke()
        p.stroke()
    }

    // Orange progress arc.
    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: 292 * s, startAngle: 90, endAngle: -120, clockwise: true)
    arc.lineWidth = 34 * s
    arc.lineCapStyle = .round
    NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.17, alpha: 1).setStroke()
    arc.stroke()

    // Knob with a soft metallic gradient.
    let knobRect = CGRect(x: center.x - 205 * s, y: center.y - 205 * s, width: 410 * s, height: 410 * s)
    let knob = NSBezierPath(ovalIn: knobRect)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14 * s), blur: 40 * s, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
    knob.fill()
    ctx.restoreGState()
    NSGradient(colors: [NSColor(calibratedWhite: 0.97, alpha: 1), NSColor(calibratedWhite: 0.70, alpha: 1)])!
        .draw(in: knob, angle: -90)
    NSColor.white.withAlphaComponent(0.6).setStroke()
    knob.lineWidth = 3 * s
    knob.stroke()

    // Indicator dot on the knob, pointing at the arc's end.
    let a = -120 * CGFloat.pi / 180
    let dot = CGPoint(x: center.x + cos(a) * 140 * s, y: center.y + sin(a) * 140 * s)
    NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: dot.x - 30 * s, y: dot.y - 30 * s, width: 60 * s, height: 60 * s)).fill()

    image.unlockFocus()
    return image
}

func png(_ image: NSImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = render(size: 1024)
for base in [16, 32, 128, 256, 512] {
    try! png(master, pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(master, pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! png(master, pixels: 1024).write(to: root.appendingPathComponent("docs/icon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
