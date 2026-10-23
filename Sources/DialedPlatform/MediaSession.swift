import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio
import MediaPlayer
import DialedCore

/// Keeps the Mac the buds' active audio source by streaming silence to them.
/// Hardware-verified: without an active stream the buds send dial turns to whichever
/// device last played audio (e.g. a phone on dual connection); with it, every turn
/// arrives on the Mac.
public final class SilentKeepAlive {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var configObserver: NSObjectProtocol?
    public private(set) var isRunning = false
    public private(set) var lastError: String?
    private var targetDevice: AudioObjectID = 0

    public init() {}

    public func start(on device: AudioObjectID) {
        if isRunning, device == targetDevice { return }
        stop()
        targetDevice = device
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        if device != 0, let unit = engine.outputNode.audioUnit {
            var dev = device
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                 &dev, UInt32(MemoryLayout<AudioObjectID>.size))
        }
        engine.attach(player)
        let format = engine.outputNode.outputFormat(forBus: 0)
        let safeFormat = format.sampleRate > 0 ? format : AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.connect(player, to: engine.mainMixerNode, format: safeFormat)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: safeFormat, frameCapacity: 4410) else { return }
        buffer.frameLength = 4410 // zero-filled = silence
        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            self.engine = engine
            self.player = player
            isRunning = true
            lastError = nil
            configObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                guard let self else { return }
                let dev = self.targetDevice
                self.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.start(on: dev) }
            }
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    public func stop() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        isRunning = false
    }
}

/// Receives the buds' presses. macOS delivers AVRCP play/pause/next/previous from a
/// headset to the "now playing" app, so Dialed registers as one while enabled and
/// steps aside completely when disabled (so the buds control music normally).
public final class RemoteCommandReceiver {
    public var onCommand: ((RemoteCommand, TimeInterval) -> Void)?
    public private(set) var isActive = false
    /// Shown in Control Center / Now Playing while Dialed holds the controls.
    public var title = "Dialed" { didSet { if isActive && !isYielding { reassert() } } }
    private var tokens: [(MPRemoteCommand, Any)] = []

    public init() {}

    public func activate() {
        guard !isActive else { reassert(); return }
        let center = MPRemoteCommandCenter.shared()
        let pairs: [(MPRemoteCommand, RemoteCommand)] = [
            (center.togglePlayPauseCommand, .togglePlayPause), (center.playCommand, .play),
            (center.pauseCommand, .pause), (center.nextTrackCommand, .nextTrack),
            (center.previousTrackCommand, .previousTrack),
        ]
        for (command, kind) in pairs {
            command.isEnabled = true
            let token = command.addTarget { [weak self] _ in
                self?.onCommand?(kind, ProcessInfo.processInfo.systemUptime)
                return .success
            }
            tokens.append((command, token))
        }
        isActive = true
        reassert()
    }

    /// Claim "now playing" again (after another app played audio).
    public func reassert() {
        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Dialed · CMF Buds Pro 2 dial",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        info.playbackState = .playing
    }

    /// Step aside completely so macOS routes media keys to the previous player
    /// (hardware-verified: only lowering playbackState still routed keys back to us).
    public func yield() {
        guard isActive else { return }
        deactivate()
        isYielding = true
    }

    /// Take the buds' presses back after `yield()`.
    public func resume() {
        guard isYielding else { return }
        isYielding = false
        activate()
    }

    public private(set) var isYielding = false

    public func deactivate() {
        guard isActive else { return }
        for (command, token) in tokens {
            command.removeTarget(token)
            command.isEnabled = false
        }
        tokens.removeAll()
        let info = MPNowPlayingInfoCenter.default()
        info.playbackState = .stopped
        info.nowPlayingInfo = nil
        isActive = false
    }
}
