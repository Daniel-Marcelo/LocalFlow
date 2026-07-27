import Foundation

/// The dictation languages LocalFlow supports. The rawValue is the whisper.cpp language code ("en"/"pt").
public enum DictationLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case portugueseBR = "pt"

    public var id: String { rawValue }

    public var whisperCode: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .portugueseBR: return "Português (Brasil)"
        }
    }

    public static let `default` = DictationLanguage.english
}
