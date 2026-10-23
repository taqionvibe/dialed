// Tiles PNG frames into one contact sheet: swift scripts/tile.swift out.png cols a.png b.png …
import AppKit
let args = CommandLine.arguments
let out = args[1], cols = Int(args[2])!, files = Array(args.dropFirst(3))
let imgs = files.compactMap { NSImage(contentsOfFile: $0) }
let w = imgs[0].size.width, h = imgs[0].size.height, pad: CGFloat = 8
let rows = (imgs.count + cols - 1) / cols
let size = NSSize(width: CGFloat(cols) * (w + pad) + pad, height: CGFloat(rows) * (h + pad) + pad)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.07, alpha: 1).setFill(); NSRect(origin: .zero, size: size).fill()
for (i, img) in imgs.enumerated() {
    let c = i % cols, r = i / cols
    img.draw(in: NSRect(x: pad + CGFloat(c) * (w + pad), y: size.height - pad - h - CGFloat(r) * (h + pad), width: w, height: h))
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
