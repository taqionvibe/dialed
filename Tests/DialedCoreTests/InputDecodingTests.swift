import XCTest
@testable import DialedCore

final class VolumeGridTests: XCTestCase {
    func testGridScalarsMatchAVRCPValuesSeenOnHardware() {
        // Values logged from CMF Buds Pro 2 on macOS 27: raw 40, 48, 56, 64, 71, 79, 87, 103.
        let expected: [Int: Int] = [5: 40, 6: 48, 7: 56, 8: 64, 9: 71, 10: 79, 11: 87, 13: 103]
        for (k, raw) in expected {
            XCTAssertEqual(VolumeGrid.scalar(forIndex: k), Float(Double(raw) / 127), accuracy: 0.0001, "k=\(k)")
            XCTAssertEqual(VolumeGrid.index(of: Float(Double(raw) / 127)), k)
        }
    }

    func testOnGridDetection() {
        XCTAssertTrue(VolumeGrid.isOnGrid(Float(71.0 / 127)))
        XCTAssertTrue(VolumeGrid.isOnGrid(1.0))
        XCTAssertTrue(VolumeGrid.isOnGrid(0))
        XCTAssertFalse(VolumeGrid.isOnGrid(0.53))   // menu-bar slider value
        XCTAssertFalse(VolumeGrid.isOnGrid(0.6))
    }

    func testRestLevelStaysOffTheEnds() {
        XCTAssertEqual(VolumeGrid.index(of: VolumeGrid.restLevel(near: 1.0)), 15)
        XCTAssertEqual(VolumeGrid.index(of: VolumeGrid.restLevel(near: 0.0)), 1)
        XCTAssertEqual(VolumeGrid.index(of: VolumeGrid.restLevel(near: 0.5)), 8)
        XCTAssertEqual(VolumeGrid.restTarget(for: 0.53), 0.53)
        XCTAssertEqual(VolumeGrid.restTarget(for: 1.0), VolumeGrid.scalar(forIndex: 15))
        XCTAssertEqual(VolumeGrid.restTarget(for: 0.01), VolumeGrid.scalar(forIndex: 1))
    }
}

final class VolumeClickDecoderTests: XCTestCase {
    /// Replays the CoreAudio volume readings captured from the real buds (slow turns,
    /// an accidental wobble, and fast spins) and checks every click is decoded.
    func testReplayOfHardwareCapture() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "raw-turns", withExtension: "log", subdirectory: "Fixtures"))
        let text = try String(contentsOf: url, encoding: .utf8)
        let decoder = VolumeClickDecoder()
        decoder.reset(level: Float(64.0 / 127))
        var clicks: [Int] = []
        for line in text.split(separator: "\n") where line.contains("VMVC = ") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard let t = Double(parts[0]), let v = Float(parts[3]) else { continue }
            if case .click(let s) = decoder.ingest(v, at: t) { clicks.append(s) }
        }
        // 3 down + 3 up (slow), a wobble while pressing, then fast spins: every report is one click.
        XCTAssertEqual(clicks, [-1, 1, -1, -1, -1, 1, 1, 1, 1, -1, 1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1])
    }

    func testOwnWritesAreEchoesNotClicks() {
        let d = VolumeClickDecoder()
        d.reset(level: VolumeGrid.scalar(forIndex: 8))
        XCTAssertEqual(d.ingest(VolumeGrid.scalar(forIndex: 7), at: 1.0), .click(steps: -1))
        d.noteOwnWrite(VolumeGrid.scalar(forIndex: 8), at: 1.02)
        // CoreAudio reports our own write back: unchanged from what we set.
        XCTAssertEqual(d.ingest(VolumeGrid.scalar(forIndex: 8), at: 1.05), .ignored("unchanged"))
        XCTAssertEqual(d.ingest(VolumeGrid.scalar(forIndex: 7), at: 2.0), .click(steps: -1))
    }

    func testDelayedEchoAfterAnotherChange() {
        let d = VolumeClickDecoder()
        d.reset(level: VolumeGrid.scalar(forIndex: 8))
        d.noteOwnWrite(VolumeGrid.scalar(forIndex: 9), at: 0)
        _ = d.ingest(VolumeGrid.scalar(forIndex: 10), at: 0.1)  // a click lands first
        XCTAssertEqual(d.ingest(VolumeGrid.scalar(forIndex: 9), at: 0.2), .echo)
    }

    func testSliderAndKeyboardChangesAreUserChanges() {
        let d = VolumeClickDecoder()
        d.reset(level: VolumeGrid.scalar(forIndex: 8))
        XCTAssertEqual(d.ingest(0.53, at: 1), .userChange(0.53))
        d.reset(level: VolumeGrid.scalar(forIndex: 8))
        d.noteVolumeKey(at: 2)
        XCTAssertEqual(d.ingest(VolumeGrid.scalar(forIndex: 9), at: 2.1), .userChange(VolumeGrid.scalar(forIndex: 9)))
        // A jump of many steps is a slider drag even if it lands on the grid.
        XCTAssertEqual(d.ingest(VolumeGrid.scalar(forIndex: 15), at: 5), .userChange(VolumeGrid.scalar(forIndex: 15)))
    }

    func testSettlingIgnoresReconnectNoise() {
        let d = VolumeClickDecoder()
        d.reset(level: VolumeGrid.scalar(forIndex: 8))
        d.settle(until: 3)
        XCTAssertEqual(d.ingest(1.0, at: 1), .ignored("settling"))
        XCTAssertEqual(d.ingest(VolumeGrid.scalar(forIndex: 15), at: 4), .click(steps: -1))
    }

    func testFirstReadingIsBaseline() {
        let d = VolumeClickDecoder()
        XCTAssertEqual(d.ingest(0.5, at: 0), .ignored("first reading"))
        XCTAssertEqual(d.lastLevel, 0.5)
    }
}

final class MotionTests: XCTestCase {
    func testSlowClicksAreExact() {
        var s = SpinTracker()
        XCTAssertEqual(s.multiplier(steps: 1, at: 0, acceleration: 1), 1)
        XCTAssertEqual(s.multiplier(steps: 1, at: 1.0, acceleration: 1), 1)
    }

    func testFastSpinAccelerates() {
        var s = SpinTracker()
        _ = s.multiplier(steps: 1, at: 0, acceleration: 1)
        XCTAssertEqual(s.multiplier(steps: 1, at: 0.55, acceleration: 1), 5, accuracy: 0.001)
        XCTAssertGreaterThan(s.multiplier(steps: 1, at: 1.1, acceleration: 0.5), 1)
    }

    func testDirectionChangeIsExact() {
        var s = SpinTracker()
        _ = s.multiplier(steps: 1, at: 0, acceleration: 1)
        XCTAssertEqual(s.multiplier(steps: -1, at: 0.3, acceleration: 1), 1)
    }

    func testAccelerationOff() {
        var s = SpinTracker()
        _ = s.multiplier(steps: 1, at: 0, acceleration: 0)
        XCTAssertEqual(s.multiplier(steps: 1, at: 0.3, acceleration: 0), 1)
    }

    func testTurnGuardWakesThenPasses() {
        var g = TurnGuard(idleThreshold: 20)
        XCTAssertEqual(g.filter(steps: 1, at: 100, guarded: true), .armed)
        XCTAssertEqual(g.filter(steps: 1, at: 101, guarded: true), .pass(1))
        XCTAssertEqual(g.filter(steps: -1, at: 110, guarded: true), .pass(-1))
        XCTAssertEqual(g.filter(steps: 1, at: 200, guarded: true), .armed)
    }

    func testTurnGuardOffForUnguardedModes() {
        var g = TurnGuard(idleThreshold: 20)
        XCTAssertEqual(g.filter(steps: 2, at: 100, guarded: false), .pass(2))
    }

    func testPressDebouncerMergesDuplicates() {
        var d = PressDebouncer()
        XCTAssertEqual(d.accept(.pause, at: 1.0), .single)
        XCTAssertNil(d.accept(.togglePlayPause, at: 1.05))
        XCTAssertEqual(d.accept(.play, at: 2.0), .single)
        XCTAssertEqual(d.accept(.nextTrack, at: 2.05), .double)
        XCTAssertEqual(d.accept(.previousTrack, at: 3), .triple)
    }
}
