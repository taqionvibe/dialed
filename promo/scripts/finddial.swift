// Finds the silver dial disc in the top-view cut-out by scanning for its grey,
// low-saturation pixels in the top-left area, then crops it as a circular PNG.
import AppKit
let path = CommandLine.arguments[1], out = CommandLine.arguments[2]
let img = NSImage(contentsOfFile: path)!
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let w = rep.pixelsWide, h = rep.pixelsHigh
var xs: [Int] = [], ys: [Int] = []
for y in 0..<Int(Double(h) * 0.5) {
    for x in 0..<Int(Double(w) * 0.45) {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.9 else { continue }
        let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
        let mx = max(r, g, b), mn = min(r, g, b)
        // Dial: darker beige-grey metal (case is brighter white).
        if mx < 0.80 && mx > 0.45 && (mx - mn) < 0.12 { xs.append(x); ys.append(y) }
    }
}
xs.sort(); ys.sort()
func pct(_ a: [Int], _ p: Double) -> Int { a[min(a.count - 1, Int(Double(a.count) * p))] }
let x0 = pct(xs, 0.01), x1 = pct(xs, 0.99), y0 = pct(ys, 0.01), y1 = pct(ys, 0.99)
var cx = Double(x0 + x1) / 2, cy = Double(y0 + y1) / 2, r = Double((x1 - x0) + (y1 - y0)) / 4
// Manual override measured from edge samples (the reflection fools the colour scan).
if CommandLine.arguments.count >= 6 { cx = Double(CommandLine.arguments[3])!; cy = Double(CommandLine.arguments[4])!; r = Double(CommandLine.arguments[5])! }
print(String(format: "center %.0f,%.0f radius %.0f (image %dx%d)", cx, cy, r, w, h))
let size = Int(r * 2)
let outRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                              hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: outRep)
NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).addClip()
// NSImage coordinates are bottom-up.
img.draw(in: NSRect(x: -(cx - r), y: -(Double(h) - cy - r), width: Double(w), height: Double(h)))
NSGraphicsContext.restoreGraphicsState()
try! outRep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
// Machine-readable for the video code.
print(String(format: "JSON {\"cx\":%.1f,\"cy\":%.1f,\"r\":%.1f,\"w\":%d,\"h\":%d}", cx, cy, r, w, h))
