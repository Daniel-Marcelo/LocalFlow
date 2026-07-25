# Task 5: Language-Aware CleanupGate

**Files:**
- Modify: `Sources/LocalFlowCore/Core/CleanupGate.swift`
- Modify: `Tests/LocalFlowTests/CleanupGateTests.swift`

**Interfaces:**
- Consumes: `DictationLanguage` (Task 1)
- Produces:
  - `CleanupGate.shouldClean(transcript:cleanupEnabled:language:) -> Bool` — new
    signature with default `language: .english`
  - `CleanupGate.needsCleanup(_:language:) -> Bool` (internal)
  - PT-BR filler pattern: `éé+|ãã+|hã+|tipo|né|então|sabe` (excludes bare `é`, which
    is the verb "to be")

> **IMPORTANT — do targeted edits, not a full-file replace.** `CleanupGate` contains a
> terminal-punctuation check whose string literal includes smart quotes
> (`".!?…\"'”’)"`). Retyping the whole file risks corrupting those characters into an
> unbalanced literal that won't compile. The steps below change only the three lines
> that need changing and never touch the punctuation line. The stutter pattern and the
> lowercase-start / terminal-punctuation checks are language-agnostic and stay shared.

---

- [ ] **Step 1: Write the failing PT-BR tests**

Add to `Tests/LocalFlowTests/CleanupGateTests.swift` (append to the existing `@Suite`):

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh --filter CleanupGateTests`
Expected: compilation failure — the `language:` parameter doesn't exist yet.

- [ ] **Step 3a: Split the filler pattern into English + Portuguese**

In `Sources/LocalFlowCore/Core/CleanupGate.swift`, find the single `fillerPattern`
constant:

```swift
    /// Filler words / phrases that mark a transcript as needing cleanup.
    /// Deliberately conservative: only unambiguous disfluencies, matched on
    /// word boundaries ("um" must not fire inside "museum").
    private static let fillerPattern =
        "\\b(um+|uh+|uhm|erm|ehm|you know|i mean)\\b"
```

Replace it with two constants (keep the comment above them):

```swift
    /// Filler words / phrases that mark a transcript as needing cleanup.
    /// Deliberately conservative: only unambiguous disfluencies, matched on
    /// word boundaries ("um" must not fire inside "museum").
    private static let englishFillerPattern =
        "\\b(um+|uh+|uhm|erm|ehm|you know|i mean)\\b"

    /// Portuguese hesitation forms and discourse crutches. Excludes bare "é"
    /// (the verb "to be") — only elongated "éé"/"ãã"/"hã" and clear filler
    /// words count, so ordinary prose isn't force-routed to the LLM.
    private static let portugueseFillerPattern =
        "\\b(éé+|ãã+|hã+|tipo|né|então|sabe)\\b"
```

- [ ] **Step 3b: Add `language` to `shouldClean`**

Find:

```swift
    public static func shouldClean(transcript: String, cleanupEnabled: Bool) -> Bool {
        cleanupEnabled && transcript.count > minimumLength && needsCleanup(transcript)
    }
```

Replace with:

```swift
    public static func shouldClean(transcript: String, cleanupEnabled: Bool, language: DictationLanguage = .english) -> Bool {
        cleanupEnabled && transcript.count > minimumLength && needsCleanup(transcript, language: language)
    }
```

- [ ] **Step 3c: Add `language` to `needsCleanup` and select the pattern**

Find the first two lines of `needsCleanup` (the signature and the filler-pattern check):

```swift
    static func needsCleanup(_ transcript: String) -> Bool {
        let options: NSString.CompareOptions = [.regularExpression, .caseInsensitive]
        if transcript.range(of: fillerPattern, options: options) != nil { return true }
```

Replace **only those three lines** with:

```swift
    static func needsCleanup(_ transcript: String, language: DictationLanguage = .english) -> Bool {
        let options: NSString.CompareOptions = [.regularExpression, .caseInsensitive]
        let fillerPattern = language == .portugueseBR ? portugueseFillerPattern : englishFillerPattern
        if transcript.range(of: fillerPattern, options: options) != nil { return true }
```

Do **not** modify the remaining lines of `needsCleanup` (the stutter check, the
lowercase-start check, and the terminal-punctuation check with its smart-quote literal
`".!?…\"'”’)"`) — they are language-agnostic and must stay byte-for-byte as they are.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh --filter CleanupGateTests`
Expected: all tests PASS — the existing English tests (which call
`shouldClean(transcript:cleanupEnabled:)` with no `language`) still pass via the default,
and the new PT-BR tests pass.

- [ ] **Step 5: Verify the full build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!` — the default argument keeps `DictationController`'s and
`PipelineCLI`'s existing `shouldClean(transcript:cleanupEnabled:)` calls compiling until
Task 7 updates them.

- [ ] **Step 6: Commit**

```bash
git add Sources/LocalFlowCore/Core/CleanupGate.swift Tests/LocalFlowTests/CleanupGateTests.swift
git commit -m "feat: add PT-BR filler detection to CleanupGate"
```
