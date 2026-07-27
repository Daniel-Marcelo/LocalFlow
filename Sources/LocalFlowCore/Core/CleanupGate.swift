import Foundation

/// Decides whether a transcript goes through the LLM cleanup stage.
/// Two filters keep latency down: short dictations are injected as-is, and
/// longer ones only visit the LLM when they actually look like they need it —
/// Whisper already punctuates well-spoken speech, so a transcript with no
/// disfluencies and sane punctuation skips the slowest pipeline stage.
public enum CleanupGate {
    public static let minimumLength = 50

    /// Filler words / phrases that mark a transcript as needing cleanup.
    /// Deliberately conservative: only unambiguous disfluencies, matched on
    /// word boundaries ("um" must not fire inside "museum").
    private static let englishFillerPattern =
        "\\b(um+|uh+|uhm|erm|ehm|you know|i mean)\\b"

    /// Portuguese hesitation forms and discourse crutches. Excludes bare "é"
    /// (the verb "to be") — only elongated "éé"/"ãã"/"hã" and clear filler
    /// words count, so ordinary prose isn't force-routed to the LLM.
    /// Note: words like "então"/"né"/"sabe"/"tipo" are also ordinary Portuguese
    /// words outside a filler role, so the gate may route some already-clean PT
    /// transcripts to the LLM anyway — a deliberate latency-only tradeoff, since
    /// the gate never affects correctness, only which stage does the cleanup.
    private static let portugueseFillerPattern =
        "\\b(éé+|ãã+|hã+|tipo|né|então|sabe)\\b"

    /// Stutter repeats: the same word twice in a row, optionally separated by
    /// a comma ("we should, should", "to to", "is, is").
    private static let stutterPattern =
        "\\b(\\w+)\\b,? +\\b\\1\\b"

    public static func shouldClean(transcript: String, cleanupEnabled: Bool, language: DictationLanguage = .english) -> Bool {
        cleanupEnabled && transcript.count > minimumLength && needsCleanup(transcript, language: language)
    }

    static func needsCleanup(_ transcript: String, language: DictationLanguage = .english) -> Bool {
        let options: NSString.CompareOptions = [.regularExpression, .caseInsensitive]
        let fillerPattern = language == .portugueseBR ? portugueseFillerPattern : englishFillerPattern
        if transcript.range(of: fillerPattern, options: options) != nil { return true }
        if transcript.range(of: stutterPattern, options: options) != nil { return true }

        if let first = transcript.unicodeScalars.first,
           CharacterSet.lowercaseLetters.contains(first) {
            return true
        }
        if let last = transcript.last, !".!?…\"'”’)".contains(last) {
            return true
        }
        return false
    }
}
