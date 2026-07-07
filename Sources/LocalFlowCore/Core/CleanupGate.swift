import Foundation

/// Decides whether a transcript goes through the LLM cleanup stage.
/// Short dictations are injected as-is to minimize latency.
public enum CleanupGate {
    public static let minimumLength = 50

    public static func shouldClean(transcript: String, cleanupEnabled: Bool) -> Bool {
        cleanupEnabled && transcript.count > minimumLength
    }
}
