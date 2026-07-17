# Task 4: Protect Vocabulary Terms During Ollama Cleanup

Self-contained. You need only this file and the repository. Independent of Tasks
1–3 (consumed later by Task 5).

## Context

`OllamaCleaner` (`Sources/LocalFlowCore/LLM/OllamaCleaner.swift`) builds the
cleanup prompt sent to the local LLM. Replacement (Task 1) only fixes mishearings
you have *already listed*; the LLM could still rewrite an unusual proper noun it
thinks is a typo. This task passes the vocabulary's canonical terms into the
prompt as a "preserve exactly" instruction.

Today the prompt is one template with the transcript formatted in at the end:

```swift
static let promptTemplate = """
You clean up dictated speech transcripts. Rewrite the transcript below by:
- Removing filler words (um, uh, you know, like, I mean, actually).
- Removing false starts and self-corrections, keeping only the corrected version.
- Fixing grammar, capitalization, and punctuation.
- Splitting the text into logical paragraphs where appropriate.

Do NOT add anything, do not summarize, and do not answer questions in the \
text — output only the cleaned version of the transcript, with no preamble \
and no quotation marks around it.

Transcript:
%@
"""
```

```swift
let body: [String: Any] = [
    "model": config.model,
    "prompt": String(format: promptTemplate, transcript),
    // ...
]
```

We restructure so the instruction block, an optional preserve line, and the
transcript are assembled in `makeRequest`. Existing tests
(`OllamaCleanerTests`) assert the prompt still contains the transcript and the
`"do not"` instruction — both remain true.

**Global constraints:** Swift 6.1, language mode v5. Tests use **Swift Testing**,
run via `./scripts/test.sh --filter OllamaCleanerTests`. Preserve list is already
capped upstream (Task 1) at 1000 chars; this task just places it in the prompt.
The new parameter defaults to `""` so the existing `clean(...)` call in
`SettingsView.testOllama()` compiles unchanged.

## Files

- Modify: `Sources/LocalFlowCore/LLM/OllamaCleaner.swift`
- Test: `Tests/LocalFlowTests/OllamaCleanerTests.swift`

## Interfaces

- Consumes: nothing (takes a plain `String`; Task 5 passes `Vocabulary.preserveList`).
- Produces:
  ```swift
  static func makeRequest(transcript: String, config: OllamaConfig, preserveList: String = "") throws -> URLRequest
  static func clean(transcript: String, config: OllamaConfig, preserveList: String = "") async -> CleanupOutcome
  ```

## Steps

- [ ] **Step 1: Write the failing tests**

Add these two tests inside `@Suite struct OllamaCleanerTests` in
`Tests/LocalFlowTests/OllamaCleanerTests.swift`:

```swift
    @Test func requestOmitsPreserveLineWhenListEmpty() throws {
        let request = try OllamaCleaner.makeRequest(
            transcript: "hello", config: OllamaConfig(), preserveList: ""
        )
        let httpBody = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let prompt = try #require(body["prompt"] as? String)
        #expect(!prompt.lowercased().contains("preserve these terms"))
    }

    @Test func requestIncludesPreserveLineWhenListProvided() throws {
        let request = try OllamaCleaner.makeRequest(
            transcript: "hello", config: OllamaConfig(), preserveList: "Claude Code, Kubernetes"
        )
        let httpBody = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.contains("Preserve these terms exactly as written"))
        #expect(prompt.contains("Claude Code, Kubernetes"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./scripts/test.sh --filter OllamaCleanerTests`
Expected: FAILS to build — `extra argument 'preserveList' in call`.

- [ ] **Step 3: Restructure the template and `makeRequest`**

In `Sources/LocalFlowCore/LLM/OllamaCleaner.swift`, replace the `promptTemplate`
declaration with an instruction-only block (no transcript tail):

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

Then change `makeRequest` to take `preserveList` and assemble the prompt:

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

- [ ] **Step 4: Thread `preserveList` through `clean`**

Change the `clean` signature and its single `makeRequest` call:

```swift
    public static func clean(
        transcript: String, config: OllamaConfig, preserveList: String = ""
    ) async -> CleanupOutcome {
        let request: URLRequest
        do {
            request = try makeRequest(transcript: transcript, config: config, preserveList: preserveList)
        } catch {
            return CleanupOutcome(text: transcript, fellBack: true, fallbackReason: "\(error)")
        }
        // ... rest of the method is unchanged ...
```

Leave the remainder of `clean` (the `URLSession` call, status handling,
`postProcess`, fallbacks) exactly as-is.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `./scripts/test.sh --filter OllamaCleanerTests`
Expected: PASS — the two new tests plus the existing ones (including
`requestBodyContainsModelTranscriptAndNoStreaming`, which still finds the
transcript and `"do not"`).

- [ ] **Step 6: Commit**

```bash
git add Sources/LocalFlowCore/LLM/OllamaCleaner.swift Tests/LocalFlowTests/OllamaCleanerTests.swift
git commit -m "feat: protect vocabulary terms during Ollama cleanup"
```
