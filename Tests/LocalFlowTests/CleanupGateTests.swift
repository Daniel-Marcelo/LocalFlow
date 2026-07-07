import Testing
@testable import LocalFlowCore

@Suite struct CleanupGateTests {
    private let longText = String(repeating: "hello there ", count: 10) // 120 chars

    @Test func shortTranscriptSkipsCleanup() {
        #expect(!CleanupGate.shouldClean(transcript: "Send it now.", cleanupEnabled: true))
    }

    @Test func exactly50CharactersSkipsCleanup() {
        let fifty = String(repeating: "a", count: 50)
        #expect(!CleanupGate.shouldClean(transcript: fifty, cleanupEnabled: true))
    }

    @Test func longTranscriptRunsCleanup() {
        #expect(CleanupGate.shouldClean(transcript: longText, cleanupEnabled: true))
    }

    @Test func disabledSettingSkipsCleanupEvenWhenLong() {
        #expect(!CleanupGate.shouldClean(transcript: longText, cleanupEnabled: false))
    }
}
