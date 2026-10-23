import Foundation
import CoreAudio
import AudioToolbox

/// A CoreAudio output device.
public struct AudioOutputDevice: Equatable, Identifiable, Sendable {
    public var id: AudioObjectID
    public var name: String
    public var uid: String
    public var isBluetooth: Bool
    public var isDefaultOutput: Bool
}

/// Thin wrappers around the CoreAudio HAL.
enum CA {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector,
                        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                        _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func deviceIDs() -> [AudioObjectID] {
        var a = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var a = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr, let v = value else { return nil }
        return v.takeRetainedValue() as String
    }

    static func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
        var a = address(selector, scope)
        var v: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v) == noErr else { return nil }
        return v
    }

    static func hasOutputStreams(_ id: AudioObjectID) -> Bool {
        var a = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr && size > 0
    }

    static var defaultOutput: AudioObjectID {
        uint32(system, kAudioHardwarePropertyDefaultOutputDevice) ?? 0
    }

    static func outputDevices() -> [AudioOutputDevice] {
        let def = defaultOutput
        return deviceIDs().compactMap { id in
            guard hasOutputStreams(id) else { return nil }
            let transport = uint32(id, kAudioDevicePropertyTransportType) ?? 0
            return AudioOutputDevice(
                id: id,
                name: string(id, kAudioObjectPropertyName) ?? "Unknown device",
                uid: string(id, kAudioDevicePropertyDeviceUID) ?? "",
                isBluetooth: transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE,
                isDefaultOutput: id == def)
        }
    }

    /// The "system volume" slider value (VirtualMainVolume), 0…1.
    static func volume(_ id: AudioObjectID) -> Float? {
        var a = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectHasProperty(id, &a) else { return channelVolume(id) }
        guard AudioHardwareServiceGetPropertyData(id, &a, 0, nil, &size, &v) == noErr else { return channelVolume(id) }
        return v
    }

    private static func channelVolume(_ id: AudioObjectID) -> Float? {
        for element: UInt32 in [0, 1] {
            var a = address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, element)
            var v: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectHasProperty(id, &a), AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v) == noErr { return v }
        }
        return nil
    }

    @discardableResult
    static func setVolume(_ id: AudioObjectID, _ value: Float) -> Bool {
        var a = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
        var v = Float32(max(0, min(1, value)))
        return AudioHardwareServiceSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    /// The property that changes once per dial report: main volume if present, else left channel.
    static func volumeNotificationAddress(_ id: AudioObjectID) -> AudioObjectPropertyAddress? {
        for element: UInt32 in [0, 1] {
            var a = address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, element)
            if AudioObjectHasProperty(id, &a) { return a }
        }
        return nil
    }
}

/// Finds the buds' audio output, re-finds it after every reconnect (macOS assigns a
/// new AudioObjectID each time), and reports every volume change on it.
public final class BudsAudioMonitor {
    public private(set) var device: AudioOutputDevice?
    public var nameMatch: String

    /// Called on the main queue for every volume change: (level, uptime).
    public var onVolume: ((Float, TimeInterval) -> Void)?
    /// Called when the buds appear or disappear.
    public var onDeviceChange: ((AudioOutputDevice?) -> Void)?
    /// Called when the system default output changes.
    public var onDefaultOutputChange: (() -> Void)?

    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var volumeAddress: AudioObjectPropertyAddress?
    private var systemListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var running = false

    public init(nameMatch: String) { self.nameMatch = nameMatch }

    deinit { stop() }

    public func start() {
        guard !running else { return }
        running = true
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var a = CA.address(selector)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                guard let self else { return }
                if selector == kAudioHardwarePropertyDefaultOutputDevice { self.onDefaultOutputChange?() }
                self.refresh()
            }
            if AudioObjectAddPropertyListenerBlock(CA.system, &a, .main, block) == noErr {
                systemListeners.append((a, block))
            }
        }
        refresh()
    }

    public func stop() {
        guard running else { return }
        running = false
        detach()
        for (addr, block) in systemListeners {
            var a = addr
            AudioObjectRemovePropertyListenerBlock(CA.system, &a, .main, block)
        }
        systemListeners.removeAll()
    }

    /// Re-scan devices; attach to the buds if they changed.
    public func refresh() {
        let match = nameMatch.trimmingCharacters(in: .whitespaces).lowercased()
        let found = CA.outputDevices().first { d in
            d.isBluetooth && (match.isEmpty || d.name.lowercased().contains(match))
        }
        if found?.id == device?.id {
            if let found { device = found } // default-output flag may have changed
            return
        }
        detach()
        device = found
        if let found { attach(found) }
        onDeviceChange?(found)
    }

    public var volume: Float? { device.flatMap { CA.volume($0.id) } }

    @discardableResult
    public func setVolume(_ value: Float) -> Bool {
        guard let d = device else { return false }
        return CA.setVolume(d.id, value)
    }

    public static func outputDevices() -> [AudioOutputDevice] { CA.outputDevices() }

    private func attach(_ d: AudioOutputDevice) {
        guard var a = CA.volumeNotificationAddress(d.id) else { return }
        let id = d.id
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, let v = CA.volume(id) else { return }
            self.onVolume?(v, ProcessInfo.processInfo.systemUptime)
        }
        if AudioObjectAddPropertyListenerBlock(id, &a, .main, block) == noErr {
            volumeListener = block
            volumeAddress = a
        }
    }

    private func detach() {
        if let d = device, var a = volumeAddress, let block = volumeListener {
            AudioObjectRemovePropertyListenerBlock(d.id, &a, .main, block)
        }
        volumeListener = nil
        volumeAddress = nil
    }
}
