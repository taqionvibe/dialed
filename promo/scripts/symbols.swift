// Renders the SF Symbols used in the reels to white transparent PNGs.
import AppKit
let names = ["speaker.wave.2.fill","arrow.up.and.down","music.note","film","sun.max.fill","plus.magnifyingglass",
             "square.on.square","play.rectangle.fill","square.grid.2x2.fill","macwindow.on.rectangle","arrow.uturn.backward",
             "circle.circle","arrow.clockwise","person.crop.rectangle.stack","wand.and.stars","heart.fill","forward.end.fill",
             "backward.end.fill","playpause.fill","keyboard","sparkles","checkmark","dial.medium.fill","command","safari.fill"]
let out = URL(fileURLWithPath: CommandLine.arguments[1])
for n in names {
    let cfg = NSImage.SymbolConfiguration(pointSize: 180, weight: .semibold).applying(.init(paletteColors: [.white]))
    guard let img = NSImage(systemSymbolName: n, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { print("missing \(n)"); continue }
    let size = NSSize(width: 256, height: 256)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = img.size, scale = min(220 / s.width, 220 / s.height)
    let w = s.width * scale, h = s.height * scale
    img.draw(in: NSRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(n.replacingOccurrences(of: ".", with: "-") + ".png"))
}
print("done")
