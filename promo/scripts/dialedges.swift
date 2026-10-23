// Prints brightness along a horizontal and a vertical line to find the disc edges.
import AppKit
let rep = NSBitmapImageRep(data: NSImage(contentsOfFile: CommandLine.arguments[1])!.tiffRepresentation!)!
func lum(_ x: Int, _ y: Int) -> String {
    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return "  -" }
    if c.alphaComponent < 0.5 { return "  ." }
    return String(format: "%3d", Int((c.redComponent + c.greenComponent + c.blueComponent) / 3 * 99))
}
print("row y=215:", stride(from: 0, through: 400, by: 10).map { "\($0):\(lum($0, 215))" }.joined(separator: " "))
print("col x=180:", stride(from: 0, through: 420, by: 10).map { "\($0):\(lum(180, $0))" }.joined(separator: " "))
