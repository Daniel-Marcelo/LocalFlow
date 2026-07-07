import Foundation

/// Converts raw PCM chunks into a 0–1 loudness value for the HUD waveform.
public enum AudioLevel {
    public static func rms(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    /// Maps an RMS amplitude to a perceptual 0–1 scale: a 50 dB window from
    /// -50 dBFS (quiet room) up to full scale, so conversational speech
    /// (~0.02–0.1 RMS) lands mid-scale instead of hugging the bottom.
    public static func normalize(rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(1, max(0, (db + 50) / 50 * 1.25))
    }
}
