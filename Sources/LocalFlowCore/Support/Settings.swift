import Foundation

public enum ActivationMode: String, CaseIterable, Identifiable {
    case hold, toggle

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hold: return "Hold to talk"
        case .toggle: return "Press to start / stop"
        }
    }
}

public enum InjectionMethod: String, CaseIterable, Identifiable {
    case paste, type

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .paste: return "Paste (fast, restores clipboard)"
        case .type: return "Type (for fields that block paste)"
        }
    }
}

/// All user-configurable state, persisted in UserDefaults. Values unknown to
/// this build (or garbage) silently fall back to defaults.
public final class Settings: ObservableObject {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Bumped on every write so SwiftUI views and observers refresh.
    @Published public private(set) var changeCounter = 0

    private func rawString(_ key: String) -> String? {
        defaults.string(forKey: key)
    }

    private func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
        changeCounter += 1
    }

    private func bool(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    private func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        changeCounter += 1
    }

    public var hotkey: HotkeyChoice {
        get { rawString("hotkey").flatMap(HotkeyChoice.init(rawValue:)) ?? .default }
        set { set(newValue.rawValue, forKey: "hotkey") }
    }

    public var activationMode: ActivationMode {
        get { rawString("activationMode").flatMap(ActivationMode.init(rawValue:)) ?? .hold }
        set { set(newValue.rawValue, forKey: "activationMode") }
    }

    public var whisperModel: WhisperModel {
        get { rawString("whisperModel").flatMap(WhisperModel.init(rawValue:)) ?? .default }
        set { set(newValue.rawValue, forKey: "whisperModel") }
    }

    public var cleanupEnabled: Bool {
        get { bool("cleanupEnabled", default: true) }
        set { set(newValue, forKey: "cleanupEnabled") }
    }

    public var ollamaModel: String {
        get { rawString("ollamaModel") ?? "gemma3:4b" }
        set { set(newValue, forKey: "ollamaModel") }
    }

    public var injectionMethod: InjectionMethod {
        get { rawString("injectionMethod").flatMap(InjectionMethod.init(rawValue:)) ?? .paste }
        set { set(newValue.rawValue, forKey: "injectionMethod") }
    }

    public var hudEnabled: Bool {
        get { bool("hudEnabled", default: true) }
        set { set(newValue, forKey: "hudEnabled") }
    }

    public var hudSize: HUDSize {
        get { rawString("hudSize").flatMap(HUDSize.init(rawValue:)) ?? .standard }
        set { set(newValue.rawValue, forKey: "hudSize") }
    }

    public var hudStyle: HUDStyle {
        get { rawString("hudStyle").flatMap(HUDStyle.init(rawValue:)) ?? .system }
        set { set(newValue.rawValue, forKey: "hudStyle") }
    }

    public var hudBehavior: HUDBehavior {
        get { rawString("hudBehavior").flatMap(HUDBehavior.init(rawValue:)) ?? .fullPipeline }
        set { set(newValue.rawValue, forKey: "hudBehavior") }
    }

    public var soundCuesEnabled: Bool {
        get { bool("soundCuesEnabled", default: true) }
        set { set(newValue, forKey: "soundCuesEnabled") }
    }

    public var ollamaConfig: OllamaConfig {
        var config = OllamaConfig()
        config.model = ollamaModel
        return config
    }
}
