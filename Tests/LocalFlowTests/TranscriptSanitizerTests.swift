import Testing
@testable import LocalFlowCore

@Suite struct TranscriptSanitizerTests {
    @Test func trimsSurroundingWhitespace() {
        #expect(TranscriptSanitizer.sanitize("  Hello world. \n") == "Hello world.")
    }

    @Test func blankAudioMarkerBecomesEmpty() {
        #expect(TranscriptSanitizer.sanitize("[BLANK_AUDIO]") == "")
    }

    @Test func silenceMarkerBecomesEmpty() {
        #expect(TranscriptSanitizer.sanitize(" [ Silence ] ") == "")
    }

    @Test func noiseAnnotationInParensIsRemoved() {
        #expect(TranscriptSanitizer.sanitize("(wind blowing) Hello there.") == "Hello there.")
    }

    @Test func inlineMarkerIsRemovedAndSpacingCollapsed() {
        #expect(TranscriptSanitizer.sanitize("Hello [BLANK_AUDIO] world") == "Hello world")
    }

    @Test func musicNotesRemoved() {
        #expect(TranscriptSanitizer.sanitize("♪ ♪") == "")
    }

    @Test func plainSpeechIsUntouched() {
        #expect(
            TranscriptSanitizer.sanitize("This is a normal, punctuated sentence.")
                == "This is a normal, punctuated sentence."
        )
    }
}
