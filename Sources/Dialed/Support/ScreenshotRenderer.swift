import AppKit
import ApplicationServices
import SwiftUI
import DialedCore

/// Renders Dialed's own windows and overlays to PNG files (for the README and
/// visual review) without needing Screen Recording permission. Debug-only hook:
///   defaults write io.github.taqionvibe.dialed EnableDebugHooks -bool YES
/// then post the distributed notification "io.github.taqionvibe.dialed.render"
/// with the output directory as its object.
@MainActor
enum ScreenshotRenderer {
    static let notification = Notification.Name("io.github.taqionvibe.dialed.render")

    static func installHook() {
        guard UserDefaults.standard.bool(forKey: "EnableDebugHooks") else { return }
        DistributedNotificationCenter.default().addObserver(forName: notification, object: nil, queue: .main) { note in
            guard let path = note.object as? String else { return }
            MainActor.assumeIsolated {
                Task { await renderAll(to: URL(fileURLWithPath: path)) }
            }
        }
    }

    static func renderAll(to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let app = AppController.shared
        let state = "accessibility=\(app.accessibilityGranted) AXIsProcessTrusted=\(AXIsProcessTrusted()) buds=\(app.buds) keepAlive=\(app.keepAliveRunning) mode=\(app.currentMode)\n"
        try? (state + app.diagnostics.exportText).write(to: dir.appendingPathComponent("diagnostics.txt"), atomically: true, encoding: .utf8)
        if UserDefaults.standard.bool(forKey: "RenderLogOnly") && !CommandLine.arguments.contains("--render-screenshots") { return }
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            await capture(MenuBarView().environmentObject(app), size: CGSize(width: 340, height: 460), fit: true,
                          name: "menubar-\(suffix)", dir: dir, appearance: appearance)
            for page in SettingsPage.allCases {
                let nav = SettingsNavigation()
                nav.page = page
                await capture(SettingsView(navigation: nav).environmentObject(app), size: CGSize(width: 900, height: 640),
                              name: "settings-\(page.rawValue)-\(suffix)", dir: dir, appearance: appearance)
            }
            await capture(DiagnosticsView(diagnostics: app.diagnostics).environmentObject(app), size: CGSize(width: 860, height: 640),
                          name: "diagnostics-\(suffix)", dir: dir, appearance: appearance)
            for step in OnboardingView.Step.allCases {
                await capture(OnboardingView(diagnostics: app.diagnostics, initialStep: step).environmentObject(app),
                              size: CGSize(width: 720, height: 560), name: "onboarding-\(step.rawValue)-\(step)-\(suffix)",
                              dir: dir, appearance: appearance)
            }
        }
        await captureOverlays(dir: dir)
        app.diagnostics.log(.system, "Rendered screenshots to \(dir.path)")
    }

    private static func captureOverlays(dir: URL) async {
        let app = AppController.shared
        let s = app.settings
        let model = RadialModel()
        model.slots = app.activeProfile.radialItems.map { item in
            var subtitle = "Press to run"
            if case .mode(let m) = item.target { subtitle = s.modeInfo(m).turnHint }
            return RadialSlot(id: item.id, title: s.label(for: item), symbol: s.symbol(for: item), subtitle: subtitle,
                              isCurrentMode: item.target == .mode(app.currentMode))
        }
        model.highlighted = 1
        model.arcPosition = 1
        model.visible = true
        await capture(Backdrop { RadialMenuView(model: model) }, size: CGSize(width: 560, height: 480),
                      name: "radial", dir: dir, appearance: .darkAqua, rounded: false)

        let hud = HUDModel()
        hud.content = HUDContent(symbol: "speaker.wave.2.fill", title: "Volume", subtitle: "56%", level: 0.56)
        hud.visible = true
        await capture(Backdrop { HUDView(model: hud) }, size: CGSize(width: 560, height: 170),
                      name: "hud-volume", dir: dir, appearance: .darkAqua, rounded: false)
        hud.content = HUDContent(symbol: "play.rectangle.fill", title: "Slides", subtitle: "→")
        await capture(Backdrop { HUDView(model: hud) }, size: CGSize(width: 560, height: 170),
                      name: "hud-slides", dir: dir, appearance: .darkAqua, rounded: false)
    }

    /// A wallpaper-like gradient so translucent overlays read as they do on screen.
    private struct Backdrop<Content: View>: View {
        @ViewBuilder var content: Content
        var body: some View {
            ZStack {
                LinearGradient(colors: [Color(red: 0.18, green: 0.2, blue: 0.32), Color(red: 0.45, green: 0.25, blue: 0.3),
                                        Color(red: 0.85, green: 0.45, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                content
            }
        }
    }

    private static func capture<V: View>(_ view: V, size: CGSize, fit: Bool = false, name: String, dir: URL,
                                         appearance: NSAppearance.Name, rounded: Bool = true) async {
        let scheme: ColorScheme = appearance == .darkAqua ? .dark : .light
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: fit ? nil : size.height)
            .background(rounded ? Color(nsColor: .windowBackgroundColor) : Color.clear)
            .environment(\.colorScheme, scheme))
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -6000, y: -6000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        // Invisible, on every Space, never activating: rendering must not move the user's Spaces.
        window.alphaValue = 0
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .transient]
        window.ignoresMouseEvents = true
        window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = .windowBackgroundColor
        window.contentView = host
        if fit {
            let fitting = host.fittingSize
            window.setContentSize(NSSize(width: size.width, height: fitting.height))
        }
        window.orderFrontRegardless()
        try? await Task.sleep(nanoseconds: 700_000_000)
        host.layoutSubtreeIfNeeded()
        let bounds = host.bounds
        guard let rep = host.bitmapImageRepForCachingDisplay(in: bounds) else { window.orderOut(nil); return }
        host.cacheDisplay(in: bounds, to: rep)
        window.orderOut(nil)

        let scale = CGFloat(rep.pixelsWide) / bounds.width
        let pad: CGFloat = rounded ? 24 : 0
        let outSize = NSSize(width: bounds.width + pad * 2, height: bounds.height + pad * 2)
        let pixels = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(outSize.width * scale), pixelsHigh: Int(outSize.height * scale),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        pixels.size = outSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: pixels)
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            if rounded {
                let rect = NSRect(x: pad, y: pad, width: bounds.width, height: bounds.height)
                let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
                NSGraphicsContext.current?.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowBlurRadius = 18
                shadow.shadowOffset = NSSize(width: 0, height: -6)
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
                shadow.set()
                (appearance == .darkAqua ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.975, alpha: 1)).setFill()
                path.fill()
                NSGraphicsContext.current?.restoreGraphicsState()
                path.addClip()
                rep.draw(in: rect)
                NSColor.black.withAlphaComponent(0.18).setStroke()
                path.lineWidth = 1
                path.stroke()
            } else {
                rep.draw(in: NSRect(origin: .zero, size: outSize))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        try? pixels.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
