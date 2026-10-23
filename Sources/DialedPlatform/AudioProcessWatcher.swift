import Foundation
import CoreAudio

/// Reports when another app starts playing audio. macOS hands the buds' presses to
/// the app that most recently started playback (hardware-verified with YouTube Music),
/// so Dialed uses this to take them back. Uses CoreAudio process objects (macOS 14.4+).
public final class AudioProcessWatcher {
    /// Called on the main queue with the bundle ID (or "pid N") of the app that started output.
    public var onOtherAppStartedOutput: ((String) -> Void)?

    private var listListener: AudioObjectPropertyListenerBlock?
    private var processListeners: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    private var running: [AudioObjectID: Bool] = [:]
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    public init() {}

    deinit { stop() }

    /// True while any other app is playing audio (and may take the buds' presses).
    public var othersPlaying: Bool { running.values.contains(true) }

    public var isSupported: Bool {
        if #available(macOS 14.4, *) { return true }
        return false
    }

    public func start() {
        guard #available(macOS 14.4, *), listListener == nil else { return }
        var a = CA.address(kAudioHardwarePropertyProcessObjectList)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.rescan() }
        if AudioObjectAddPropertyListenerBlock(CA.system, &a, .main, block) == noErr { listListener = block }
        rescan(initial: true)
    }

    public func stop() {
        guard #available(macOS 14.4, *) else { return }
        if let block = listListener {
            var a = CA.address(kAudioHardwarePropertyProcessObjectList)
            AudioObjectRemovePropertyListenerBlock(CA.system, &a, .main, block)
        }
        listListener = nil
        for (id, block) in processListeners {
            var a = CA.address(kAudioProcessPropertyIsRunningOutput)
            AudioObjectRemovePropertyListenerBlock(id, &a, .main, block)
        }
        processListeners.removeAll()
        running.removeAll()
    }

    @available(macOS 14.4, *)
    private func processIDs() -> [AudioObjectID] {
        var a = CA.address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(CA.system, &a, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(CA.system, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    @available(macOS 14.4, *)
    private func rescan(initial: Bool = false) {
        let ids = Set(processIDs())
        for (id, block) in processListeners where !ids.contains(id) {
            var a = CA.address(kAudioProcessPropertyIsRunningOutput)
            AudioObjectRemovePropertyListenerBlock(id, &a, .main, block)
            processListeners[id] = nil
            running[id] = nil
        }
        for id in ids where processListeners[id] == nil {
            let pid = Int32(bitPattern: CA.uint32(id, kAudioProcessPropertyPID) ?? 0)
            guard pid != ownPID else { continue }
            var a = CA.address(kAudioProcessPropertyIsRunningOutput)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.check(id) }
            if AudioObjectAddPropertyListenerBlock(id, &a, .main, block) == noErr {
                processListeners[id] = block
                running[id] = isRunningOutput(id)
                if !initial, running[id] == true { report(id) }
            }
        }
    }

    @available(macOS 14.4, *)
    private func isRunningOutput(_ id: AudioObjectID) -> Bool {
        (CA.uint32(id, kAudioProcessPropertyIsRunningOutput) ?? 0) != 0
    }

    private func check(_ id: AudioObjectID) {
        guard #available(macOS 14.4, *) else { return }
        let now = isRunningOutput(id)
        let before = running[id] ?? false
        running[id] = now
        if now && !before { report(id) }
    }

    @available(macOS 14.4, *)
    private func report(_ id: AudioObjectID) {
        let name = CA.string(id, kAudioProcessPropertyBundleID)
            ?? "pid \(Int32(bitPattern: CA.uint32(id, kAudioProcessPropertyPID) ?? 0))"
        onOtherAppStartedOutput?(name)
    }
}
