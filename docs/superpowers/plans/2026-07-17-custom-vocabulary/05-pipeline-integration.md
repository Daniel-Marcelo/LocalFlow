# Task 5: Pipeline Integration

Self-contained. You need only this file and the repository. **Depends on Tasks 1,
2, 3, 4** (`Vocabulary`, `Settings.vocabulary`, `transcribe(samples:initialPrompt:)`,
`OllamaCleaner.clean(…, preserveList:)`).

## Context

`DictationController` (`Sources/LocalFlowCore/Core/DictationController.swift`)
orchestrates the loop. This task wires the three vocabulary touch-points into it:

1. **Priming** — snapshot the current `Vocabulary` in `process(samples:)`, derive
   `primingPrompt`, and pass it into `transcribe`.
2. **Preserve** — pass `vocabulary.preserveList` into `OllamaCleaner.clean`.
3. **Replacement** — apply `vocabulary.applyReplacements(_:)` to the final text
   **unconditionally**, right before injection, so it fixes mishearings on both
   the cleaned path and the gate-skipped raw path.

`process(samples:)` already snapshots settings before hopping to `whisperQueue`;
we add the vocabulary snapshot alongside. The `Vocabulary` value is carried into
`cleanAndInject` (which runs on `@MainActor`). This is I/O-bound orchestration
around a real model and daemon, so there is **no unit test** — the pure logic is
already covered by `VocabularyTests`/`OllamaCleanerTests`; verify the wiring with
a clean build, the full suite, and one manual dictation.

Current `process(samples:)`:

```swift
    private func process(samples: [Float]) {
        setState(.transcribing)
        let model = settings.whisperModel
        let cleanupEnabled = settings.cleanupEnabled
        let ollamaConfig = settings.ollamaConfig
        let injectionMethod = settings.injectionMethod

        whisperQueue.async { [weak self, transcriber] in
            let transcript: String
            do {
                try transcriber.load(model: model)
                transcript = TranscriptSanitizer.sanitize(
                    try transcriber.transcribe(samples: samples)
                )
            } catch {
                Task { @MainActor [weak self] in
                    self?.setState(.error(error.localizedDescription))
                    self?.scheduleErrorReset()
                }
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.cleanAndInject(
                    transcript: transcript,
                    cleanupEnabled: cleanupEnabled,
                    ollamaConfig: ollamaConfig,
                    injectionMethod: injectionMethod
                )
            }
        }
    }
```

Current `cleanAndInject(...)`:

```swift
    private func cleanAndInject(
        transcript: String,
        cleanupEnabled: Bool,
        ollamaConfig: OllamaConfig,
        injectionMethod: InjectionMethod
    ) async {
        guard !transcript.isEmpty else {
            log.info("Empty transcript; nothing to inject")
            setState(.idle)
            return
        }

        var finalText = transcript
        if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanupEnabled) {
            setState(.cleaning)
            let outcome = await OllamaCleaner.clean(transcript: transcript, config: ollamaConfig)
            finalText = outcome.text
            warning = outcome.fellBack
                ? "LLM cleanup unavailable (\(outcome.fallbackReason ?? "unknown")) — injected raw transcript"
                : nil
        }

        TextInjector.inject(finalText, method: injectionMethod)
        setState(.idle)
    }
```

**Global constraints:** Swift 6.1, language mode v5. `LocalFlowCore` module. The
whisper queue already captures a non-`Sendable` `transcriber` under language mode
v5, so capturing the `Vocabulary` value is consistent with the existing code.

## Files

- Modify: `Sources/LocalFlowCore/Core/DictationController.swift`

## Interfaces

- Consumes: `Vocabulary`, `Settings.vocabulary`,
  `transcribe(samples:initialPrompt:)`, `OllamaCleaner.clean(…, preserveList:)`.
- Produces: no new public API — internal wiring only.

## Steps

- [ ] **Step 1: Snapshot vocabulary and pass the priming prompt into `transcribe`**

Replace the body of `process(samples:)` with:

```swift
    private func process(samples: [Float]) {
        setState(.transcribing)
        let model = settings.whisperModel
        let cleanupEnabled = settings.cleanupEnabled
        let ollamaConfig = settings.ollamaConfig
        let injectionMethod = settings.injectionMethod
        let vocabulary = Vocabulary(entries: settings.vocabulary)
        let primingPrompt = vocabulary.primingPrompt

        whisperQueue.async { [weak self, transcriber] in
            let transcript: String
            do {
                try transcriber.load(model: model)
                transcript = TranscriptSanitizer.sanitize(
                    try transcriber.transcribe(samples: samples, initialPrompt: primingPrompt)
                )
            } catch {
                Task { @MainActor [weak self] in
                    self?.setState(.error(error.localizedDescription))
                    self?.scheduleErrorReset()
                }
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.cleanAndInject(
                    transcript: transcript,
                    cleanupEnabled: cleanupEnabled,
                    ollamaConfig: ollamaConfig,
                    injectionMethod: injectionMethod,
                    vocabulary: vocabulary
                )
            }
        }
    }
```

- [ ] **Step 2: Apply preserve + replacement in `cleanAndInject`**

Replace `cleanAndInject(...)` with:

```swift
    private func cleanAndInject(
        transcript: String,
        cleanupEnabled: Bool,
        ollamaConfig: OllamaConfig,
        injectionMethod: InjectionMethod,
        vocabulary: Vocabulary
    ) async {
        guard !transcript.isEmpty else {
            log.info("Empty transcript; nothing to inject")
            setState(.idle)
            return
        }

        var finalText = transcript
        if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanupEnabled) {
            setState(.cleaning)
            let outcome = await OllamaCleaner.clean(
                transcript: transcript, config: ollamaConfig, preserveList: vocabulary.preserveList
            )
            finalText = outcome.text
            warning = outcome.fellBack
                ? "LLM cleanup unavailable (\(outcome.fallbackReason ?? "unknown")) — injected raw transcript"
                : nil
        }

        // Deterministic vocabulary fixes run last, on both the cleaned and the
        // gate-skipped raw path, so known mishearings always come out right.
        finalText = vocabulary.applyReplacements(finalText)

        TextInjector.inject(finalText, method: injectionMethod)
        setState(.idle)
    }
```

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: build succeeds with no errors.

- [ ] **Step 4: Verify no regression in the full suite**

Run: `make test`
Expected: the entire suite passes.

- [ ] **Step 5: Manual end-to-end check**

The `--transcribe` CLI does not carry vocabulary (out of scope), so verify in the
running app:

```bash
make app
open LocalFlow.app
```

In Settings (this uses the editor from Task 6 if already built; otherwise add one
entry directly in code or defer this check until after Task 6), add:
`Term = "Claude Code"`, `Also heard as = "clod code"`. Then hold the hotkey and
say a sentence containing "clod code" and a proper noun. Confirm the injected
text shows "Claude Code" (replacement) and that proper nouns come out better
(priming). With an empty vocabulary, dictation must behave exactly as before.

> If executing tasks in order, Task 6 (the editor UI) is not built yet — it is
> fine to defer the *interactive* part of this manual check until after Task 6
> and confirm here only that `swift build` and `make test` are green.

- [ ] **Step 6: Commit**

```bash
git add Sources/LocalFlowCore/Core/DictationController.swift
git commit -m "feat: wire custom vocabulary into the dictation pipeline"
```
