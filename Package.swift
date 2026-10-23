// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Dialed",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Dialed", targets: ["Dialed"]),
        .library(name: "DialedCore", targets: ["DialedCore"]),
    ],
    targets: [
        // Pure logic: click decoding, gestures, modes, settings. No AppKit, fully unit-tested.
        .target(name: "DialedCore"),
        // macOS integrations: CoreAudio, MediaPlayer, CGEvent output, brightness, Shortcuts.
        .target(
            name: "DialedPlatform",
            dependencies: ["DialedCore"],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("MediaPlayer"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        // The menu bar app (SwiftUI + AppKit panels).
        .executableTarget(
            name: "Dialed",
            dependencies: ["DialedCore", "DialedPlatform"]
        ),
        .testTarget(
            name: "DialedCoreTests",
            dependencies: ["DialedCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
