import Testing
@testable import LocalFlowCore

@Suite struct CleanupGateTests {
    // Long, disfluent, unpunctuated — clearly needs the LLM.
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

    // MARK: Prefilter — transcripts that already look clean skip the LLM

    @Test func cleanPunctuatedTranscriptSkipsCleanupEvenWhenLong() {
        let clean = "Whisper already punctuates well-spoken sentences. This one needs no LLM pass at all."
        #expect(clean.count > CleanupGate.minimumLength)
        #expect(!CleanupGate.shouldClean(transcript: clean, cleanupEnabled: true))
    }

    @Test func fillerWordsTriggerCleanup() {
        let text = "So um, I was thinking that we could deploy the new version on Thursday afternoon."
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true))
    }

    @Test func youKnowAndIMeanTriggerCleanup() {
        let a = "The dashboard is, you know, mostly finished and the tests are green already now."
        let b = "We should ship it Friday, I mean Thursday, right after the standup meeting ends."
        #expect(CleanupGate.shouldClean(transcript: a, cleanupEnabled: true))
        #expect(CleanupGate.shouldClean(transcript: b, cleanupEnabled: true))
    }

    @Test func stutterRepeatsTriggerCleanup() {
        let text = "We need to to finalize the budget before the deadline arrives next Friday morning."
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true))
    }

    @Test func stutterRepeatWithCommaTriggersCleanup() {
        let text = "Tuesday is, is really busy for everyone so let's find another day for the meeting."
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true))
    }

    @Test func missingTerminalPunctuationTriggersCleanup() {
        let text = "This transcript is long enough to qualify but whisper never closed the sentence"
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true))
    }

    @Test func lowercaseStartTriggersCleanup() {
        let text = "this long transcript starts in lowercase which real prose would not normally do."
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true))
    }

    @Test func fillerAsPartOfARealWordDoesNotTrigger() {
        // "um" inside "umbrella"/"museum", "uh" inside nothing common — word
        // boundaries must be respected.
        let text = "The museum lent us an umbrella stand for the exhibition opening on Saturday night."
        #expect(!CleanupGate.shouldClean(transcript: text, cleanupEnabled: true))
    }

    // MARK: Portuguese-specific filler detection

    @Test func ptFillerFormsTriggerCleanup() {
        let cases = [
            "Então éé, eu acho que a gente deveria revisar o código antes de fazer o deploy na sexta.",
            "Tipo, eu não sei se isso vai funcionar porque a gente não testou o suficiente ainda.",
            "Eu acho que a gente deveria, né, testar mais antes de colocar em produção para o cliente.",
            "Sabe, o problema é que a gente não tem tempo suficiente para resolver tudo isso agora.",
            "Ãã, deixa eu pensar um pouco sobre isso antes de dar uma resposta definitiva para vocês.",
        ]
        for text in cases {
            #expect(
                CleanupGate.shouldClean(transcript: text, cleanupEnabled: true, language: .portugueseBR),
                "Should trigger for: \(text.prefix(30))…"
            )
        }
    }

    @Test func ptBareEDoesNotTrigger() {
        let text = "Eu acho que é importante revisar o código antes de fazer o deploy para produção na sexta."
        #expect(!CleanupGate.shouldClean(transcript: text, cleanupEnabled: true, language: .portugueseBR))
    }

    @Test func ptCleanTranscriptSkipsCleanup() {
        let text = "Precisamos revisar o pull request antes do deploy na sexta-feira para garantir a qualidade."
        #expect(text.count > CleanupGate.minimumLength)
        #expect(!CleanupGate.shouldClean(transcript: text, cleanupEnabled: true, language: .portugueseBR))
    }

    @Test func ptStutterRepeatsTriggerCleanup() {
        let text = "A gente precisa precisa terminar isso antes do prazo que foi combinado com o cliente."
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true, language: .portugueseBR))
    }

    @Test func ptLowercaseStartTriggersCleanup() {
        let text = "precisamos revisar o pull request antes de fazer o deploy na sexta para garantir qualidade."
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true, language: .portugueseBR))
    }

    @Test func ptMissingPunctuationTriggersCleanup() {
        let text = "Precisamos revisar o pull request antes de fazer o deploy na sexta para garantir qualidade"
        #expect(CleanupGate.shouldClean(transcript: text, cleanupEnabled: true, language: .portugueseBR))
    }

    @Test func englishBehaviourUnchangedWithExplicitLanguage() {
        let clean = "Whisper already punctuates well-spoken sentences. This one needs no LLM pass at all."
        #expect(!CleanupGate.shouldClean(transcript: clean, cleanupEnabled: true, language: .english))
        let dirty = "So um, I was thinking that we could deploy the new version on Thursday afternoon."
        #expect(CleanupGate.shouldClean(transcript: dirty, cleanupEnabled: true, language: .english))
    }
}
