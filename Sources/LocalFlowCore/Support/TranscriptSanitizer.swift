import Foundation

/// Cleans Whisper's raw output before it goes anywhere else: strips the
/// non-speech annotations Whisper emits ("[BLANK_AUDIO]", "[ Silence ]",
/// "(wind blowing)", "♪") and normalizes whitespace. Returns "" when the
/// utterance contained no actual speech.
public enum TranscriptSanitizer {
    private static let noisePatterns = [
        "\\[[^\\]]*\\]", // [BLANK_AUDIO], [ Silence ], [MUSIC] …
        "\\([^)]*\\)",   // (wind blowing), (coughs) …
        "♪",
    ]

    public static func sanitize(_ raw: String) -> String {
        var text = raw
        for pattern in noisePatterns {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
