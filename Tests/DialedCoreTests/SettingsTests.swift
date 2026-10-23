import XCTest
@testable import DialedCore

final class SettingsTests: XCTestCase {
    func testRoundTrip() throws {
        var s = DialedSettings()
        s.customModes = [CustomMode(name: "Lines", clockwise: .keyboardShortcut(combo: KeyCombo(KeyCode.downArrow)),
                                    counterClockwise: .keyboardShortcut(combo: KeyCombo(KeyCode.upArrow)))]
        s.macros = [Macro(name: "Standup", steps: [.action(.openApplication(bundleID: "com.apple.Notes", name: "Notes")),
                                                     .wait(milliseconds: 500),
                                                     .action(.typeText(text: "Yesterday:"))])]
        s.profiles += DialedSettings.suggestedProfiles()
        s.profiles[0].gestures.triple = .action(.runMacro(id: s.macros[0].id))
        let data = try SettingsStore.encoder().encode(s)
        let back = try JSONDecoder().decode(DialedSettings.self, from: data)
        XCTAssertEqual(back, s)
    }

    func testPartialFileFallsBackToDefaults() throws {
        let json = #"{"enabled": false, "general": {"showHUD": false}}"#
        let s = try JSONDecoder().decode(DialedSettings.self, from: Data(json.utf8))
        XCTAssertFalse(s.enabled)
        XCTAssertFalse(s.general.showHUD)
        XCTAssertEqual(s.general.radialTimeout, 6)
        XCTAssertEqual(s.profiles.count, 1)
        XCTAssertEqual(s.sensitivity, Sensitivity())
    }

    func testRepairDropsDeletedReferences() {
        var s = DialedSettings()
        let ghost = ModeID.custom(UUID())
        s.profiles[0].radialItems.append(RadialItem(target: .mode(ghost)))
        s.profiles[0].radialItems.append(RadialItem(target: .action(.runMacro(id: UUID()))))
        s.general.startMode = ghost
        s.sensitivity.scrollPixelsPerClick = 99999
        let notes = s.repair()
        XCTAssertEqual(s.profiles[0].radialItems, Profile.defaultRadialItems)
        XCTAssertEqual(s.general.startMode, BuiltinMode.volume.id)
        XCTAssertEqual(s.sensitivity.scrollPixelsPerClick, 800)
        XCTAssertEqual(notes.count, 2)
    }

    func testExportImportRoundTrip() throws {
        var s = DialedSettings()
        s.sensitivity.acceleration = 0.2
        let data = try SettingsStore.exportData(s, at: Date(timeIntervalSince1970: 0))
        let (back, notes) = try SettingsStore.importData(data)
        XCTAssertEqual(back, s)
        XCTAssertTrue(notes.isEmpty)
    }

    func testImportRejectsOtherFiles() {
        XCTAssertThrowsError(try SettingsStore.importData(Data("hello".utf8))) {
            XCTAssertEqual($0 as? SettingsError, .unreadable("It isn’t valid JSON."))
        }
        XCTAssertThrowsError(try SettingsStore.importData(Data(#"{"name": "x"}"#.utf8))) {
            XCTAssertEqual($0 as? SettingsError, .notDialedSettings)
        }
        XCTAssertThrowsError(try SettingsStore.importData(Data(#"{"app": "Other", "settings": {}}"#.utf8))) {
            XCTAssertEqual($0 as? SettingsError, .notDialedSettings)
        }
    }

    func testImportRejectsNewerSchema() {
        XCTAssertThrowsError(try SettingsStore.importData(Data(#"{"schemaVersion": 99, "profiles": []}"#.utf8))) {
            XCTAssertEqual($0 as? SettingsError, .newerSchema(99))
        }
    }

    func testImportExplainsBadTypes() {
        let json = #"{"app": "Dialed", "exportedAt": "2026-01-01T00:00:00Z", "settings": {"enabled": "yes"}}"#
        XCTAssertThrowsError(try SettingsStore.importData(Data(json.utf8))) { error in
            XCTAssertTrue(error.localizedDescription.contains("settings.enabled"), error.localizedDescription)
        }
    }

    func testStoreSurvivesDamagedFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("settings.json")
        try Data("{not json".utf8).write(to: url)
        let (s, warning) = SettingsStore(url: url).load()
        XCTAssertTrue(s.enabled)
        XCTAssertEqual(s.profiles.count, 1)
        XCTAssertNotNil(warning)
        try SettingsStore(url: url).save(s)
        XCTAssertNil(SettingsStore(url: url).load().warning)
    }

    func testProfileResolver() {
        var s = DialedSettings()
        s.profiles += DialedSettings.suggestedProfiles()
        XCTAssertEqual(ProfileResolver.profile(for: "com.apple.iWork.Keynote", in: s.profiles)?.name, "Presentations")
        XCTAssertEqual(ProfileResolver.profile(for: "com.apple.finder", in: s.profiles)?.name, "Everywhere")
        XCTAssertEqual(ProfileResolver.profile(for: nil, in: s.profiles)?.name, "Everywhere")
    }

    func testMacroExpansionStopsRecursion() {
        let id = UUID()
        let loop = Macro(id: id, name: "Loop", steps: [.action(.typeText(text: "a")), .action(.runMacro(id: id))])
        let steps = loop.expanded { $0 == id ? loop : nil }
        XCTAssertEqual(steps.count, 4) // depth limit 4 → "a" four times, no infinite loop
    }

    func testLabelsAndSymbols() {
        let s = DialedSettings()
        XCTAssertEqual(s.label(for: .mode(.tabs)), "Browser Tabs")
        XCTAssertEqual(s.symbol(for: .mode(.volume)), "speaker.wave.2.fill")
        XCTAssertEqual(KeyCombo(KeyCode.z, [.command, .shift]).displayString, "⇧⌘Z")
        XCTAssertEqual(Action.keyboardShortcut(combo: KeyCombo(KeyCode.tab, .control)).summary(), "Press ⌃⇥")
    }
}
