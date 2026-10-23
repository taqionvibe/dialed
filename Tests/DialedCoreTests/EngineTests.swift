import XCTest
@testable import DialedCore

final class DialEngineTests: XCTestCase {
    private func engine(_ configure: (inout DialedSettings) -> Void = { _ in }) -> DialEngine {
        var s = DialedSettings()
        configure(&s)
        return DialEngine(settings: s)
    }

    func testStartsInVolumeAndPassesVolumeTurns() {
        let e = engine()
        XCTAssertEqual(e.mode, BuiltinMode.volume.id)
        XCTAssertEqual(e.handle(.turn(steps: 1, at: 0)), [.output(.volumeChanged(steps: 1), mode: e.mode)])
    }

    func testDoublePressOpensMenuOnCurrentMode() {
        let e = engine()
        let effects = e.handle(.press(.double, at: 0))
        guard case .menuOpened(let m) = effects.first else { return XCTFail("\(effects)") }
        XCTAssertEqual(m.highlightedItem?.target, .mode(BuiltinMode.volume.id))
    }

    func testMenuTurnWrapsAndSingleSelects() {
        let e = engine()
        _ = e.handle(.press(.double, at: 0))
        _ = e.handle(.turn(steps: -1, at: 1))   // wraps to the last item
        let count = e.settings.defaultProfile.radialItems.count
        XCTAssertEqual(e.menu?.highlighted, count - 1)
        _ = e.handle(.turn(steps: 2, at: 1.5))  // back past 0 to 1 (Scroll)
        let effects = e.handle(.press(.single, at: 2))
        XCTAssertEqual(e.mode, BuiltinMode.scroll.id)
        XCTAssertNil(e.menu)
        XCTAssertTrue(effects.contains(.modeChanged(to: BuiltinMode.scroll.id, from: BuiltinMode.volume.id)))
    }

    func testMenuTurnsAreNeverAccelerated() {
        let e = engine()
        _ = e.handle(.press(.double, at: 0))
        _ = e.handle(.turn(steps: 1, at: 0.1))
        _ = e.handle(.turn(steps: 1, at: 0.2))
        XCTAssertEqual(e.menu?.highlighted, 2)
    }

    func testDoubleOrTriplePressClosesMenuWithoutChange() {
        let e = engine()
        _ = e.handle(.press(.double, at: 0))
        _ = e.handle(.turn(steps: 3, at: 1))
        XCTAssertEqual(e.handle(.press(.double, at: 2)), [.menuClosed(selected: nil)])
        XCTAssertEqual(e.mode, BuiltinMode.volume.id)
    }

    func testMenuTimeoutSelectsHighlightedMode() {
        let e = engine()
        _ = e.handle(.press(.double, at: 0))
        _ = e.handle(.turn(steps: 1, at: 1))
        XCTAssertEqual(e.tick(now: 2), [])
        _ = e.tick(now: 1 + e.settings.general.radialTimeout)
        XCTAssertEqual(e.mode, BuiltinMode.scroll.id)
    }

    func testMenuTimeoutNeverFiresActions() {
        let e = engine { s in
            s.profiles[0].radialItems = [RadialItem(target: .action(.system(command: .lockScreen)))]
        }
        _ = e.handle(.press(.double, at: 0))
        XCTAssertEqual(e.tick(now: 100), [.menuClosed(selected: nil)])
    }

    func testTriplePressGoesBack() {
        let e = engine()
        XCTAssertEqual(e.handle(.press(.triple, at: 0)), [.nothingToDo("No previous mode yet")])
        _ = e.switchMode(BuiltinMode.zoom.id)
        _ = e.handle(.press(.triple, at: 1))
        XCTAssertEqual(e.mode, BuiltinMode.volume.id)
        _ = e.handle(.press(.triple, at: 2))
        XCTAssertEqual(e.mode, BuiltinMode.zoom.id)
    }

    func testSinglePressUsesModeDefault() {
        let e = engine()
        XCTAssertEqual(e.handle(.press(.single, at: 0)),
                       [.output(.perform(.media(command: .playPause), count: 1), mode: e.mode)])
        _ = e.switchMode(BuiltinMode.slides.id)
        XCTAssertEqual(e.handle(.press(.single, at: 1)),
                       [.output(.key(KeyCombo(KeyCode.b), count: 1), mode: BuiltinMode.slides.id)])
    }

    func testCustomGestureBindings() {
        let e = engine { s in
            s.profiles[0].gestures.single = .action(.appleShortcut(name: "Focus"))
            s.profiles[0].gestures.triple = .action(.switchMode(mode: BuiltinMode.brightness.id))
        }
        XCTAssertEqual(e.handle(.press(.single, at: 0)), [.run(.appleShortcut(name: "Focus"))])
        _ = e.handle(.press(.triple, at: 1))
        XCTAssertEqual(e.mode, BuiltinMode.brightness.id)
    }

    func testAccidentalTurnGuardInUndoMode() {
        let e = engine()
        _ = e.switchMode(BuiltinMode.undo.id)
        XCTAssertEqual(e.handle(.turn(steps: -1, at: 100)), [.armed(BuiltinMode.undo.id)])
        XCTAssertEqual(e.handle(.turn(steps: -1, at: 101)),
                       [.output(.key(KeyCombo(KeyCode.z, .command), count: 1), mode: BuiltinMode.undo.id)])
    }

    func testGuardCanBeTurnedOff() {
        let e = engine { $0.general.accidentalTurnGuard = false }
        _ = e.switchMode(BuiltinMode.undo.id)
        XCTAssertEqual(e.handle(.turn(steps: -1, at: 100)).count, 1)
        if case .armed = e.handle(.turn(steps: -1, at: 1000)).first { XCTFail("guard should be off") }
    }

    func testReverseDirection() {
        let e = engine { $0.sensitivity.reverseDirection = true }
        _ = e.switchMode(BuiltinMode.slides.id)
        XCTAssertEqual(e.handle(.turn(steps: 1, at: 0)),
                       [.output(.key(KeyCombo(KeyCode.leftArrow), count: 1), mode: BuiltinMode.slides.id)])
    }

    func testFastScrollIsAccelerated() {
        let e = engine { $0.sensitivity.acceleration = 1; $0.sensitivity.scrollPixelsPerClick = 100 }
        _ = e.switchMode(BuiltinMode.scroll.id)
        XCTAssertEqual(e.handle(.turn(steps: 1, at: 0)), [.output(.scroll(points: 100, horizontal: false), mode: e.mode)])
        XCTAssertEqual(e.handle(.turn(steps: 1, at: 0.45)), [.output(.scroll(points: 300, horizontal: false), mode: e.mode)])
    }

    func testScrollPressTogglesAxis() {
        let e = engine()
        _ = e.switchMode(BuiltinMode.scroll.id)
        _ = e.handle(.press(.single, at: 0))
        XCTAssertTrue(e.horizontalScroll)
        XCTAssertEqual(e.handle(.turn(steps: 1, at: 5)).first,
                       .output(.scroll(points: e.settings.sensitivity.scrollPixelsPerClick, horizontal: true), mode: e.mode))
    }

    func testCustomModeRepeatsOnFastSpinOnlyWhenAsked() {
        let custom = CustomMode(name: "Lines", clockwise: .keyboardShortcut(combo: KeyCombo(KeyCode.downArrow)),
                                counterClockwise: .keyboardShortcut(combo: KeyCombo(KeyCode.upArrow)),
                                press: .typeText(text: "hi"), repeatOnFastSpin: true)
        let e = engine { s in s.customModes = [custom]; s.sensitivity.acceleration = 1 }
        _ = e.switchMode(custom.modeID)
        _ = e.handle(.turn(steps: 1, at: 0))
        XCTAssertEqual(e.handle(.turn(steps: 1, at: 0.45)),
                       [.output(.perform(.keyboardShortcut(combo: KeyCombo(KeyCode.downArrow)), count: 3), mode: custom.modeID)])
        XCTAssertEqual(e.handle(.press(.single, at: 1)), [.output(.perform(.typeText(text: "hi"), count: 1), mode: custom.modeID)])
    }

    func testProfileActivationSwitchesStartMode() {
        let e = engine()
        var p = DialedSettings.suggestedProfiles()[0]
        p.startMode = BuiltinMode.slides.id
        _ = e.activate(profile: p)
        XCTAssertEqual(e.mode, BuiltinMode.slides.id)
        XCTAssertEqual(e.profile.name, "Presentations")
    }

    func testSwitchingToDeletedModeIsRefused() {
        let e = engine()
        XCTAssertEqual(e.switchMode(.custom(UUID())), [.nothingToDo("That mode no longer exists")])
        XCTAssertEqual(e.mode, BuiltinMode.volume.id)
    }

    func testRadialActionItemRuns() {
        let e = engine { s in s.profiles[0].radialItems = [RadialItem(target: .action(.system(command: .missionControl)))] }
        _ = e.handle(.press(.double, at: 0))
        let effects = e.handle(.press(.single, at: 1))
        XCTAssertEqual(effects.last, .run(.system(command: .missionControl)))
    }
}

final class ModePlannerTests: XCTestCase {
    let s = DialedSettings()

    private func turn(_ m: BuiltinMode, _ steps: Int) -> [OutputCommand] {
        ModePlanner.turn(mode: m.id, steps: steps, multiplier: 1, settings: s, profile: s.defaultProfile)
    }

    func testEveryBuiltinModeProducesOutputBothWays() {
        for m in BuiltinMode.allCases {
            XCTAssertFalse(turn(m, 1).isEmpty, "\(m) cw")
            XCTAssertFalse(turn(m, -1).isEmpty, "\(m) ccw")
            XCTAssertFalse(ModePlanner.press(mode: m.id, settings: s).isEmpty, "\(m) press")
        }
    }

    func testKeyMappings() {
        XCTAssertEqual(turn(.zoom, 2), [.key(KeyCombo(KeyCode.equal, .command), count: 2)])
        XCTAssertEqual(turn(.tabs, -1), [.key(KeyCombo(KeyCode.tab, [.control, .shift]), count: 1)])
        XCTAssertEqual(turn(.undo, 1), [.key(KeyCombo(KeyCode.z, [.command, .shift]), count: 1)])
        XCTAssertEqual(turn(.windows, 1), [.key(KeyCombo(KeyCode.grave, .command), count: 1)])
        XCTAssertEqual(turn(.media, -2), [.perform(.media(command: .previousTrack), count: 2)])
        XCTAssertEqual(turn(.apps, -1), [.appSwitch(steps: -1)])
        XCTAssertEqual(turn(.brightness, 1), [.brightness(delta: s.sensitivity.brightnessStep)])
    }

    func testProfileSensitivityScalesScroll() {
        var p = s.defaultProfile
        p.sensitivityScale = 2
        XCTAssertEqual(ModePlanner.turn(mode: BuiltinMode.scroll.id, steps: 1, multiplier: 1, settings: s, profile: p),
                       [.scroll(points: s.sensitivity.scrollPixelsPerClick * 2, horizontal: false)])
    }
}
