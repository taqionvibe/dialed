// Lifts the foreground subject (hand + case) out of a photo with Apple's Vision
// framework and writes a transparent PNG: swift scripts/cutout.swift in.jpg out.png
import AppKit
import Vision
import CoreImage

let inURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let ci = CIImage(contentsOf: inURL, options: [.applyOrientationProperty: true]) else { fatalError("can't read") }
let handler = VNImageRequestHandler(ciImage: ci)
let request = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([request])
guard let result = request.results?.first else { fatalError("no subject found") }
print("instances:", result.allInstances.count)
let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
let masked = CIImage(cvPixelBuffer: buffer)
let ctx = CIContext()
guard let cg = ctx.createCGImage(masked, from: masked.extent) else { fatalError("render") }
let rep = NSBitmapImageRep(cgImage: cg)
try rep.representation(using: .png, properties: [:])!.write(to: outURL)
print("wrote", outURL.lastPathComponent, cg.width, "x", cg.height)
