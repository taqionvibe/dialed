import Foundation

public enum SettingsError: LocalizedError, Equatable {
    case unreadable(String)
    case notDialedSettings
    case newerSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let reason):
            return "This file couldn’t be read as Dialed settings. \(reason)"
        case .notDialedSettings:
            return "This file isn’t a Dialed settings export. Export one from Settings → General → Export…"
        case .newerSchema(let v):
            return "These settings come from a newer version of Dialed (format \(v)). Update Dialed to import them."
        }
    }
}

/// Reads and writes settings JSON. File I/O is atomic; a broken file is backed up
/// and replaced with defaults rather than crashing the app.
public struct SettingsStore {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Dialed", isDirectory: true).appendingPathComponent("settings.json")
    }

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public func load() -> (settings: DialedSettings, warning: String?) {
        guard let data = try? Data(contentsOf: url) else { return (DialedSettings(), nil) }
        do {
            var s = try Self.decode(data)
            s.repair()
            return (s, nil)
        } catch {
            let backup = url.deletingPathExtension().appendingPathExtension("broken-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return (DialedSettings(), "Your settings file was damaged, so Dialed started with defaults. The old file was kept as \(backup.lastPathComponent).")
        }
    }

    public func save(_ settings: DialedSettings) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder().encode(settings).write(to: url, options: .atomic)
    }

    // MARK: Import / export

    private struct Envelope: Codable {
        var app: String
        var exportedAt: Date
        var settings: DialedSettings
    }

    public static func exportData(_ settings: DialedSettings, at date: Date = Date()) throws -> Data {
        let e = encoder()
        e.dateEncodingStrategy = .iso8601
        return try e.encode(Envelope(app: "Dialed", exportedAt: date, settings: settings))
    }

    /// Accepts an export envelope or a bare settings file. Returns repaired settings
    /// plus notes about anything that had to be fixed.
    public static func importData(_ data: Data) throws -> (DialedSettings, [String]) {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SettingsError.unreadable("It isn’t valid JSON.")
        }
        var settings: DialedSettings
        if object["app"] != nil {
            guard object["app"] as? String == "Dialed" else { throw SettingsError.notDialedSettings }
            do { settings = try d.decode(Envelope.self, from: data).settings }
            catch { throw SettingsError.unreadable(Self.describe(error)) }
        } else if object["profiles"] != nil || object["schemaVersion"] != nil {
            settings = try decode(data)
        } else {
            throw SettingsError.notDialedSettings
        }
        if settings.schemaVersion > DialedSettings.currentSchema {
            throw SettingsError.newerSchema(settings.schemaVersion)
        }
        let notes = settings.repair()
        return (settings, notes)
    }

    static func decode(_ data: Data) throws -> DialedSettings {
        do { return try JSONDecoder().decode(DialedSettings.self, from: data) }
        catch { throw SettingsError.unreadable(describe(error)) }
    }

    static func describe(_ error: Error) -> String {
        guard let e = error as? DecodingError else { return error.localizedDescription }
        switch e {
        case .keyNotFound(let key, let ctx):
            return "Missing “\(key.stringValue)” at \(path(ctx))."
        case .typeMismatch(_, let ctx), .valueNotFound(_, let ctx):
            return "Unexpected value at \(path(ctx))."
        case .dataCorrupted(let ctx):
            return "Damaged data at \(path(ctx))."
        @unknown default:
            return "Unknown format problem."
        }
    }

    private static func path(_ ctx: DecodingError.Context) -> String {
        let p = ctx.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        return p.isEmpty ? "the top level" : p
    }
}
