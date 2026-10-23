// Renders the DMG window background (Resources/dmg-background.png and @2x).
// Run: swift scripts/make-dmg-background.swift
// Layout must match scripts/dmg-settings.py: window 660×420, app icon at (170, 205),
// Applications at (490, 205), icon size 128.
import AppKit

let width: CGFloat = 660, height: CGFloat = 420
let orange = NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.17, alpha: 1)

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)

    // Deep graphite gradient with a warm glow behind the app icon.
    NSGradient(colors: [NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1),
                        NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)])!.draw(in: bounds, angle: -90)
    NSGradient(colors: [orange.withAlphaComponent(0.28), orange.withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: 170, y: 215), radius: 0, toCenter: NSPoint(x: 170, y: 215), radius: 190, options: [])

    // Faint dial ticks across the top, echoing the app icon.
    for i in 0..<48 {
        let x = 30 + CGFloat(i) * 12.6
        let tall = i % 4 == 0
        let tick = NSBezierPath(rect: NSRect(x: x, y: height - (tall ? 30 : 24), width: 2, height: tall ? 14 : 8))
        NSColor.white.withAlphaComponent(tall ? 0.16 : 0.08).setFill()
        tick.fill()
    }

    func text(_ s: String, _ font: NSFont, _ color: NSColor, centerX: CGFloat, y: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: NSPoint(x: centerX - size.width / 2, y: y), withAttributes: attrs)
    }

    text("Install Dialed", .systemFont(ofSize: 22, weight: .bold), .white, centerX: width / 2, y: height - 72)
    text("Drag Dialed into your Applications folder", .systemFont(ofSize: 13, weight: .regular),
         NSColor.white.withAlphaComponent(0.65), centerX: width / 2, y: height - 96)

    // Curved arrow from the app to Applications.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 262, y: 222))
    arrow.curve(to: NSPoint(x: 392, y: 222), controlPoint1: NSPoint(x: 300, y: 252), controlPoint2: NSPoint(x: 354, y: 252))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    orange.setStroke()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 376, y: 238))
    head.line(to: NSPoint(x: 394, y: 221))
    head.line(to: NSPoint(x: 372, y: 212))
    head.lineWidth = 5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // First-launch hint card.
    let card = NSRect(x: 120, y: 34, width: 420, height: 58)
    NSColor.white.withAlphaComponent(0.06).setFill()
    NSBezierPath(roundedRect: card, xRadius: 12, yRadius: 12).fill()
    NSColor.white.withAlphaComponent(0.12).setStroke()
    let border = NSBezierPath(roundedRect: card.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
    border.lineWidth = 1
    border.stroke()
    text("First launch: right-click Dialed → Open", .systemFont(ofSize: 13, weight: .semibold),
         NSColor.white.withAlphaComponent(0.9), centerX: width / 2, y: 64)
    text("Then follow the setup guide in the menu bar.", .systemFont(ofSize: 11.5, weight: .regular),
         NSColor.white.withAlphaComponent(0.55), centerX: width / 2, y: 45)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
for (scale, name) in [(CGFloat(1), "dmg-background.png"), (2, "dmg-background@2x.png")] {
    let data = render(scale: scale).representation(using: .png, properties: [:])!
    try! data.write(to: root.appendingPathComponent("Resources/\(name)"))
}
print("Wrote Resources/dmg-background.png and @2x")
