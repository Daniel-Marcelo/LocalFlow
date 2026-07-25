# Task 4: WhisperTranscriber Language Parameter

**Files:**
- Modify: `Sources/LocalFlowCore/STT/WhisperTranscriber.swift`

**Interfaces:**
- Consumes: `DictationLanguage` (Task 1)
- Produces: `WhisperTranscriber.transcribe(samples:initialPrompt:language:) throws -> String`
  — the hardcoded `"en"` inside the nested `run` closure becomes
  `language.whisperCode`. A new `language: .english` default is appended **after**
  the existing `initialPrompt` parameter, so the vocabulary-priming call site keeps
  compiling and the vocabulary feature is preserved.

> **IMPORTANT — current code shape:** `transcribe` already takes
> `initialPrompt: String = ""` (vocabulary priming, merged recently), and the
> language string is set **inside a nested `func run(_:)` closure**, not at the top
> level. Do not remove `initialPrompt`. The edits below target the real current code.

---

- [ ] **Step 1: Change the `transcribe` signature to append `language`**

In `Sources/LocalFlowCore/STT/WhisperTranscriber.swift`, find the current signature
(around line 65):

```swift
public func transcribe(samples: [Float], initialPrompt: String = "") throws -> String {
```

Replace it with (add `language` **after** `initialPrompt`, keep `initialPrompt`):

```swift
public func transcribe(samples: [Float], initialPrompt: String = "", language: DictationLanguage = .english) throws -> String {
```

- [ ] **Step 2: Replace the hardcoded language inside the nested `run` closure**

Still inside `transcribe`, find the nested `run` closure (around lines 88–96):

```swift
        func run(_ params: whisper_full_params) -> Int32 {
            var params = params
            return "en".withCString { english in
                params.language = english
                return padded.withUnsafeBufferPointer { buffer in
                    whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
```

Replace it with (only the language binding changes; `run` captures the new
`language` parameter from the enclosing scope):

```swift
        func run(_ params: whisper_full_params) -> Int32 {
            var params = params
            return language.whisperCode.withCString { langCode in
                params.language = langCode
                return padded.withUnsafeBufferPointer { buffer in
                    whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
```

Leave the rest of `transcribe` (the `initialPrompt.isEmpty` branch that calls
`run(params)` vs. sets `params.initial_prompt`) exactly as it is — it already routes
`initialPrompt` correctly and now runs with the selected language.

- [ ] **Step 3: Verify the full build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!` — the appended default argument means the existing
`DictationController` call `transcribe(samples: samples, initialPrompt: primingPrompt)`
still compiles unchanged.

- [ ] **Step 4: Run all tests to verify no regression**

Run: `make test`
Expected: all existing tests pass. `WhisperTranscriber` has no unit tests (it needs a
real model file + audio); the build proves API compatibility, and the headless CLI
(Task 7) exercises transcription end-to-end in Portuguese during final verification.

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalFlowCore/STT/WhisperTranscriber.swift
git commit -m "feat: add language parameter to WhisperTranscriber.transcribe"
```
