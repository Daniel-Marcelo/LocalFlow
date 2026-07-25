# Task 7: Pipeline Integration (DictationController + PipelineCLI)

**Files:**
- Modify: `Sources/LocalFlowCore/Core/DictationController.swift`
- Modify: `Sources/LocalFlowCore/Core/PipelineCLI.swift`

**Interfaces:**
- Consumes:
  - `DictationLanguage` (Task 1)
  - `Settings.language` (Task 3)
  - `WhisperTranscriber.transcribe(samples:initialPrompt:language:)` (Task 4)
  - `CleanupGate.shouldClean(transcript:cleanupEnabled:language:)` (Task 5)
  - `OllamaCleaner.clean(transcript:config:preserveList:language:)` (Task 6)
- Produces:
  - `DictationController.process` threads `settings.language` through the full pipeline,
    **alongside** the existing vocabulary wiring
  - `PipelineCLI` gains `--language en|pt`

> **IMPORTANT — the pipeline already carries vocabulary state.** `process` builds
> `let vocabulary = Vocabulary(entries: settings.vocabulary)` and
> `let primingPrompt = vocabulary.primingPrompt`, calls
> `transcribe(samples:initialPrompt:)`, and passes `vocabulary` into `cleanAndInject`,
> which calls `OllamaCleaner.clean(...preserveList: vocabulary.preserveList)`. The edits
> below add `language` **next to** that wiring — never remove `initialPrompt`,
> `vocabulary`, or `preserveList`.

---

- [ ] **Step 1: Capture `settings.language` in `process`**

In `Sources/LocalFlowCore/Core/DictationController.swift`, find the top of
`process(samples:)`:

```swift
    private func process(samples: [Float]) {
        setState(.transcribing)
        let model = settings.whisperModel
        let cleanupEnabled = settings.cleanupEnabled
        let ollamaConfig = settings.ollamaConfig
        let injectionMethod = settings.injectionMethod
        let vocabulary = Vocabulary(entries: settings.vocabulary)
        let primingPrompt = vocabulary.primingPrompt
```

Replace with (adds one line — `let language`):

```swift
    private func process(samples: [Float]) {
        setState(.transcribing)
        let model = settings.whisperModel
        let language = settings.language
        let cleanupEnabled = settings.cleanupEnabled
        let ollamaConfig = settings.ollamaConfig
        let injectionMethod = settings.injectionMethod
        let vocabulary = Vocabulary(entries: settings.vocabulary)
        let primingPrompt = vocabulary.primingPrompt
```

- [ ] **Step 2: Pass `language` to the transcriber (keep `initialPrompt`)**

In the same method, find:

```swift
                transcript = TranscriptSanitizer.sanitize(
                    try transcriber.transcribe(samples: samples, initialPrompt: primingPrompt)
                )
```

Replace with:

```swift
                transcript = TranscriptSanitizer.sanitize(
                    try transcriber.transcribe(samples: samples, initialPrompt: primingPrompt, language: language)
                )
```

- [ ] **Step 3: Pass `language` into the `cleanAndInject` call (keep `vocabulary`)**

Find the call:

```swift
                await self.cleanAndInject(
                    transcript: transcript,
                    cleanupEnabled: cleanupEnabled,
                    ollamaConfig: ollamaConfig,
                    injectionMethod: injectionMethod,
                    vocabulary: vocabulary
                )
```

Replace with (add `language:` before `vocabulary:`):

```swift
                await self.cleanAndInject(
                    transcript: transcript,
                    cleanupEnabled: cleanupEnabled,
                    ollamaConfig: ollamaConfig,
                    injectionMethod: injectionMethod,
                    language: language,
                    vocabulary: vocabulary
                )
```

- [ ] **Step 4: Update the `cleanAndInject` signature**

Find:

```swift
    private func cleanAndInject(
        transcript: String,
        cleanupEnabled: Bool,
        ollamaConfig: OllamaConfig,
        injectionMethod: InjectionMethod,
        vocabulary: Vocabulary
    ) async {
```

Replace with (insert `language:` before `vocabulary:` to match the call order):

```swift
    private func cleanAndInject(
        transcript: String,
        cleanupEnabled: Bool,
        ollamaConfig: OllamaConfig,
        injectionMethod: InjectionMethod,
        language: DictationLanguage,
        vocabulary: Vocabulary
    ) async {
```

- [ ] **Step 5: Pass `language` to the gate and the cleaner (keep `preserveList`)**

Inside `cleanAndInject`, find:

```swift
        if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanupEnabled) {
            setState(.cleaning)
            let outcome = await OllamaCleaner.clean(
                transcript: transcript, config: ollamaConfig, preserveList: vocabulary.preserveList
            )
```

Replace with:

```swift
        if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanupEnabled, language: language) {
            setState(.cleaning)
            let outcome = await OllamaCleaner.clean(
                transcript: transcript, config: ollamaConfig,
                preserveList: vocabulary.preserveList, language: language
            )
```

Leave the rest of `cleanAndInject` (the `warning` handling, `vocabulary.applyReplacements`,
`TextInjector.inject`) unchanged.

- [ ] **Step 6: Verify DictationController compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 7: Add a `--language` flag and language-defaulted model to PipelineCLI**

In `Sources/LocalFlowCore/Core/PipelineCLI.swift`, find the local state at the top of
`run`:

```swift
        var audioPath: String?
        var model = WhisperModel.default
        var cleanup = true
        var ollamaModel = "gemma3:4b"
```

Replace with (make `model` optional so we can default it per-language, add `language`):

```swift
        var audioPath: String?
        var model: WhisperModel?
        var cleanup = true
        var ollamaModel = "gemma3:4b"
        var language = DictationLanguage.default
```

- [ ] **Step 8: Add the `--language` case to the argument switch**

Find the `--ollama-model` case:

```swift
            case "--ollama-model":
                ollamaModel = iterator.next() ?? ollamaModel
```

Add a `--language` case right after it:

```swift
            case "--ollama-model":
                ollamaModel = iterator.next() ?? ollamaModel
            case "--language":
                if let raw = iterator.next(), let parsed = DictationLanguage(rawValue: raw) {
                    language = parsed
                } else {
                    fputs("Unknown language; valid: \(DictationLanguage.allCases.map(\.rawValue).joined(separator: ", "))\n", stderr)
                    return 2
                }
```

- [ ] **Step 9: Resolve the model after parsing and update the usage string**

Find the usage guard:

```swift
        guard let audioPath else {
            fputs("Usage: LocalFlow --transcribe <audio-file> [--model base.en|small.en|large-v3-turbo] [--no-cleanup] [--ollama-model name]\n", stderr)
            return 2
        }
```

Replace with (add `--language` to the usage text and resolve the per-language default
model when `--model` was not supplied):

```swift
        guard let audioPath else {
            fputs("Usage: LocalFlow --transcribe <audio-file> [--language en|pt] [--model base.en|small.en|large-v3-turbo|base|small] [--no-cleanup] [--ollama-model name]\n", stderr)
            return 2
        }
        let resolvedModel = model ?? .default(for: language)
```

- [ ] **Step 10: Use `resolvedModel` and `language` in the pipeline body**

The rest of `run` references `model` in several places (download check, load, prints).
Change each `model` reference in the body to `resolvedModel`, and thread `language`
through the pipeline calls. Specifically:

Find:

```swift
            let manager = ModelManager()
            if !model.isDownloaded {
                print("Downloading \(model.fileName) (\(model.approximateSize))…")
```

Replace with:

```swift
            let manager = ModelManager()
            if !resolvedModel.isDownloaded {
                print("Downloading \(resolvedModel.fileName) (\(resolvedModel.approximateSize))…")
```

Find:

```swift
                _ = try await manager.ensureAvailable(model)
                progressTask.cancel()
            }

            let transcriber = WhisperTranscriber()
            print("Loading \(model.rawValue)…")
            try transcriber.load(model: model)

            let start = Date()
            let raw = try transcriber.transcribe(samples: samples)
```

Replace with:

```swift
                _ = try await manager.ensureAvailable(resolvedModel)
                progressTask.cancel()
            }

            let transcriber = WhisperTranscriber()
            print("Loading \(resolvedModel.rawValue)…")
            try transcriber.load(model: resolvedModel)

            let start = Date()
            let raw = try transcriber.transcribe(samples: samples, language: language)
```

Find:

```swift
            if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanup) {
                var config = OllamaConfig()
                config.model = ollamaModel
                print("Cleaning with \(config.model) via Ollama…")
                let outcome = await OllamaCleaner.clean(transcript: transcript, config: config)
```

Replace with:

```swift
            if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanup, language: language) {
                var config = OllamaConfig()
                config.model = ollamaModel
                print("Cleaning with \(config.model) via Ollama…")
                let outcome = await OllamaCleaner.clean(transcript: transcript, config: config, language: language)
```

(The `--model` case body stays `model = parsed` — it now assigns to the optional.)

- [ ] **Step 11: Verify the full build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 12: Run all tests**

Run: `make test`
Expected: all tests PASS.

- [ ] **Step 13: Manually verify Portuguese transcription end-to-end**

Generate Brazilian-Portuguese test audio with a pt-BR voice and run the headless
pipeline (downloads the `small` multilingual model on first run):

```bash
say -v Luciana -o pt.aiff "então tipo, a gente precisa precisa revisar o código antes do deploy"
.build/release/LocalFlow --transcribe pt.aiff --language pt
```

Expected: `TRANSCRIPT:` is Portuguese text (not translated to English). If Ollama is
running with the configured model, `CLEANED:` is punctuated Portuguese with the "tipo"
filler and the "precisa precisa" stutter removed, still in Portuguese. If your build
lacks the full Metal toolchain, prefix the command with
`GGML_METAL_PATH_RESOURCES=Vendor/metal-resources` (per CLAUDE.md) to keep GPU inference.

- [ ] **Step 14: Commit**

```bash
git add Sources/LocalFlowCore/Core/DictationController.swift Sources/LocalFlowCore/Core/PipelineCLI.swift
git commit -m "feat: wire language through DictationController and PipelineCLI"
```
