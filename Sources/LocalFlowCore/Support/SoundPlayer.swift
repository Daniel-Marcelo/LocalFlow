import AppKit

/// Start/stop dictation cues using built-in system sounds.
public enum SoundPlayer {
    public static func playStart() {
        NSSound(named: "Tink")?.play()
    }

    public static func playStop() {
        NSSound(named: "Pop")?.play()
    }

    public static func playError() {
        NSSound(named: "Basso")?.play()
    }
}
