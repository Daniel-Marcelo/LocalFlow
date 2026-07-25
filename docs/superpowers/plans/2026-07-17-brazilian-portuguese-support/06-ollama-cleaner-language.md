# Task 6: Language-Aware OllamaCleaner

**Files:**
- Modify: `Sources/LocalFlowCore/LLM/OllamaCleaner.swift`
- Modify: `Tests/LocalFlowTests/OllamaCleanerTests.swift`

**Interfaces:**
- Consumes: `DictationLanguage` (Task 1)
- Produces:
  - `OllamaCleaner.instructionTemplate(for: DictationLanguage) -> String`
  - `OllamaCleaner.makeRequest(transcript:config:preserveList:language:) throws -> URLRequest`
  - `OllamaCleaner.clean(transcript:config:preserveList:language:) async -> CleanupOutcome`
  - `OllamaCleaner.postProcess(_:) -> String` — also strips a Portuguese preamble line
    (runs English and Portuguese patterns; language-agnostic)

> **IMPORTANT — preserve the custom-vocabulary feature.** The current `OllamaCleaner`
> builds the prompt as `instruction + optional preserve-line + "Transcript:\n" +
> transcript` and exposes a `preserveList` parameter on both `makeRequest` and `clean`.
> **Keep `preserveList`.** Do NOT revert to a single `%@` template. The `language`
> argument is added *after* `preserveList` on both functions (both default so existing
> call sites — including `SettingsView.testOllama` and the vocabulary tests — keep
> compiling). English output stays byte-for-byte identical except for one added
> "do not translate" clause inside the instruction, which no existing test asserts against.

---

- [ ] **Step 1: Write the failing tests**

Add to `Tests/LocalFlowTests/OllamaCleanerTests.swift` (append to the existing `@Suite`):

```swift
// MARK: Language-aware prompt selection

@Test func englishInstructionContainsNeverTranslate() {
    #expect(OllamaCleaner.instructionTemplate(for: .english).lowercased().contains("do not translate"))
}

@Test func portugueseInstructionContainsNeverTranslate() {
    #expect(OllamaCleaner.instructionTemplate(for: .portugueseBR).lowercased().contains("não traduz"))
}

@Test func requestDefaultsToEnglishInstruction() throws {
    let request = try OllamaCleaner.makeRequest(transcript: "hello", config: OllamaConfig())
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    let prompt = try #require(json["prompt"] as? String)
    #expect(prompt.contains("Removing filler words"))
    #expect(prompt.contains("Transcript:"))
    #expect(prompt.lowercased().contains("do not translate"))
}

@Test func requestUsesPortuguesePromptForPTBR() throws {
    let request = try OllamaCleaner.makeRequest(
        transcript: "oi tudo bem", config: OllamaConfig(), language: .portugueseBR
    )
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    let prompt = try #require(json["prompt"] as? String)
    #expect(prompt.contains("tipo"))
    #expect(prompt.contains("né"))
    #expect(prompt.contains("Transcrição:"))
    #expect(prompt.contains("oi tudo bem"))
    #expect(prompt.lowercased().contains("não traduz"))
}

@Test func portuguesePreserveLineIsLocalized() throws {
    let request = try OllamaCleaner.makeRequest(
        transcript: "x", config: OllamaConfig(), preserveList: "Kubernetes", language: .portugueseBR
    )
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    let prompt = try #require(json["prompt"] as? String)
    #expect(prompt.contains("Mantenha os seguintes termos"))
    #expect(prompt.contains("Kubernetes"))
}

@Test func postProcessStripsPTPreamble() {
    #expect(OllamaCleaner.postProcess("Aqui está o texto corrigido:\nOlá, mundo.") == "Olá, mundo.")
    #expect(OllamaCleaner.postProcess("Segue a versão corrigida:\nOlá, mundo.") == "Olá, mundo.")
    #expect(OllamaCleaner.postProcess("Versão corrigida:\nOlá, mundo.") == "Olá, mundo.")
}

@Test func postProcessStillStripsEnglishPreamble() {
    #expect(OllamaCleaner.postProcess("Here is the cleaned text:\nHello, world.") == "Hello, world.")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh --filter OllamaCleanerTests`
Expected: compilation failure — `instructionTemplate(for:)` and the `language:` parameter
don't exist yet.

- [ ] **Step 3: Replace the instruction constant with language-aware templates**

In `Sources/LocalFlowCore/LLM/OllamaCleaner.swift`, find the current single constant
(around lines 33–43):

```swift
    static let instructionTemplate = """
    You clean up dictated speech transcripts. Rewrite the transcript below by:
    - Removing filler words (um, uh, you know, like, I mean, actually).
    - Removing false starts and self-corrections, keeping only the corrected version.
    - Fixing grammar, capitalization, and punctuation.
    - Splitting the text into logical paragraphs where appropriate.

    Do NOT add anything, do not summarize, and do not answer questions in the \
    text — output only the cleaned version of the transcript, with no preamble \
    and no quotation marks around it.
    """
```

Replace it with two private templates plus a selector (the English text is identical
except the final paragraph now also says "do not translate — keep the input language"):

```swift
    private static let englishInstruction = """
    You clean up dictated speech transcripts. Rewrite the transcript below by:
    - Removing filler words (um, uh, you know, like, I mean, actually).
    - Removing false starts and self-corrections, keeping only the corrected version.
    - Fixing grammar, capitalization, and punctuation.
    - Splitting the text into logical paragraphs where appropriate.

    Do NOT add anything, do not summarize, do not answer questions in the \
    text, and do not translate — keep the input language. Output only the \
    cleaned version of the transcript, with no preamble and no quotation \
    marks around it.
    """

    private static let portugueseInstruction = """
    Você limpa transcrições de fala ditada. Reescreva a transcrição abaixo:
    - Removendo palavras de preenchimento (é, tipo, né, então, sabe, aí).
    - Removendo falsos inícios e autocorreções, mantendo apenas a versão corrigida.
    - Corrigindo gramática, acentuação, maiúsculas e pontuação.
    - Dividindo o texto em parágrafos lógicos quando fizer sentido.

    NÃO adicione nada, não resuma, não responda perguntas contidas no texto e \
    não traduza — mantenha o idioma original. Produza apenas a versão limpa da \
    transcrição, sem preâmbulo e sem aspas ao redor.
    """

    public static func instructionTemplate(for language: DictationLanguage) -> String {
        switch language {
        case .english: return englishInstruction
        case .portugueseBR: return portugueseInstruction
        }
    }

    private static func preserveInstruction(for language: DictationLanguage, terms: String) -> String {
        switch language {
        case .english:
            return "Preserve these terms exactly as written; do not change their spelling: \(terms)."
        case .portugueseBR:
            return "Mantenha os seguintes termos exatamente como estão escritos, sem alterar a grafia: \(terms)."
        }
    }

    private static func transcriptLabel(for language: DictationLanguage) -> String {
        switch language {
        case .english: return "Transcript:"
        case .portugueseBR: return "Transcrição:"
        }
    }
```

- [ ] **Step 4: Make `makeRequest` language-aware (keeping `preserveList`)**

Find the current `makeRequest` (around lines 47–72):

```swift
    public static func makeRequest(
        transcript: String, config: OllamaConfig, preserveList: String = ""
    ) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeout

        var prompt = instructionTemplate
        if !preserveList.isEmpty {
            prompt += "\nPreserve these terms exactly as written; do not change their spelling: \(preserveList)."
        }
        prompt += "\n\nTranscript:\n\(transcript)"

        let body: [String: Any] = [
            "model": config.model,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": 0.0],
            // Keep the model resident between dictations so cleanup stays fast.
            "keep_alive": "30m",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
```

Replace it with (adds `language`, routes every user-facing string through the selectors;
for `.english` with an empty preserve list the output is byte-for-byte identical to the
old behaviour except the instruction's added "do not translate" clause):

```swift
    public static func makeRequest(
        transcript: String, config: OllamaConfig, preserveList: String = "",
        language: DictationLanguage = .english
    ) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeout

        var prompt = instructionTemplate(for: language)
        if !preserveList.isEmpty {
            prompt += "\n" + preserveInstruction(for: language, terms: preserveList)
        }
        prompt += "\n\n" + transcriptLabel(for: language) + "\n" + transcript

        let body: [String: Any] = [
            "model": config.model,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": 0.0],
            // Keep the model resident between dictations so cleanup stays fast.
            "keep_alive": "30m",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
```

- [ ] **Step 5: Add a Portuguese preamble stripper to `postProcess`**

Find the English preamble-stripping block inside `postProcess`:

```swift
        let lines = text.components(separatedBy: "\n")
        if let first = lines.first,
           first.range(
               of: "^(sure[,!. ]*)?(okay[,!. ]*)?(here('s| is)? )?(the )?(cleaned|corrected|revised)[^:]*: *$",
               options: [.regularExpression, .caseInsensitive]
           ) != nil {
            text = lines.dropFirst().joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
```

Replace that block with a version that also strips a Portuguese preamble line
(both patterns are tried; the English pattern is unchanged so English behaviour is
preserved):

```swift
        let lines = text.components(separatedBy: "\n")
        let preamblePatterns = [
            "^(sure[,!. ]*)?(okay[,!. ]*)?(here('s| is)? )?(the )?(cleaned|corrected|revised)[^:]*: *$",
            "^(aqui (está|vai)|segue|versão|texto)\\b[^:]*: *$",
        ]
        if let first = lines.first,
           preamblePatterns.contains(where: {
               first.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
           }) {
            text = lines.dropFirst().joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
```

- [ ] **Step 6: Make `clean` language-aware (keeping `preserveList`)**

Find the current `clean` signature and its `makeRequest` call:

```swift
    public static func clean(
        transcript: String, config: OllamaConfig, preserveList: String = ""
    ) async -> CleanupOutcome {
        let request: URLRequest
        do {
            request = try makeRequest(transcript: transcript, config: config, preserveList: preserveList)
        } catch {
```

Replace those lines with (add `language` after `preserveList`, forward it):

```swift
    public static func clean(
        transcript: String, config: OllamaConfig, preserveList: String = "",
        language: DictationLanguage = .english
    ) async -> CleanupOutcome {
        let request: URLRequest
        do {
            request = try makeRequest(
                transcript: transcript, config: config,
                preserveList: preserveList, language: language
            )
        } catch {
```

Leave the rest of `clean` (the URLSession call, HTTP status handling, `postProcess`,
fallbacks) and `warmUp` and `parseResponse` exactly as they are.

- [ ] **Step 7: Run tests to verify they pass**

Run: `./scripts/test.sh --filter OllamaCleanerTests`
Expected: all tests PASS — the existing tests (`requestOmitsPreserveLineWhenListEmpty`,
`requestIncludesPreserveLineWhenListProvided`, `requestBodyContainsModelTranscriptAndNoStreaming`,
`postProcessStripsPreambleLabel`, etc.) still pass, and the new language tests pass.

- [ ] **Step 8: Verify the full build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!` — the defaulted `language` argument keeps existing call
sites (`SettingsView.testOllama`, `DictationController`, `PipelineCLI`) compiling.

- [ ] **Step 9: Commit**

```bash
git add Sources/LocalFlowCore/LLM/OllamaCleaner.swift Tests/LocalFlowTests/OllamaCleanerTests.swift
git commit -m "feat: add PT-BR prompt and language param to OllamaCleaner"
```
