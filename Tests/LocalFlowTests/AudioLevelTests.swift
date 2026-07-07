import Testing
@testable import LocalFlowCore

@Suite struct AudioLevelTests {
    @Test func silenceIsZero() {
        #expect(AudioLevel.normalize(rms: 0) == 0)
    }

    @Test func typicalSpeechLandsMidScale() {
        // RMS around 0.02–0.1 is normal conversational speech level.
        let level = AudioLevel.normalize(rms: 0.05)
        #expect(level > 0.3 && level < 0.9)
    }

    @Test func loudInputSaturatesAtOne() {
        #expect(AudioLevel.normalize(rms: 0.5) == 1)
        #expect(AudioLevel.normalize(rms: 2.0) == 1)
    }

    @Test func monotonicallyIncreasing() {
        let values = [0.001, 0.005, 0.02, 0.05, 0.1, 0.3].map { AudioLevel.normalize(rms: Float($0)) }
        #expect(values == values.sorted())
    }

    @Test func rmsOfKnownBuffer() {
        // RMS of a constant-amplitude buffer is that amplitude.
        let buffer = [Float](repeating: 0.1, count: 1600)
        #expect(abs(AudioLevel.rms(of: buffer) - 0.1) < 0.0001)
        #expect(AudioLevel.rms(of: []) == 0)
    }
}
