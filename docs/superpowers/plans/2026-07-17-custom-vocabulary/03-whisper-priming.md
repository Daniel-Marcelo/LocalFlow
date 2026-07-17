# Task 3: Whisper Priming (`initial_prompt`)

Self-contained. You need only this file and the repository. Independent of Tasks
1–2 (consumed later by Task 5).

## Context

`WhisperTranscriber` (`Sources/LocalFlowCore/STT/WhisperTranscriber.swift`) wraps
the whisper.cpp C API. This task lets a caller pass an `initial_prompt` string
that biases the decoder toward the user's vocabulary terms.

`whisper.h` (vendored) exposes the field:

```c
// tokens to provide to the whisper decoder as initial prompt
// maximum of whisper_n_text_ctx()/2 tokens are used (typically 224)
const char * initial_prompt;
```

**Pointer lifetime is the subtle part:** `initial_prompt` is a borrowed C string
that must stay valid for the duration of the `whisper_full` call. Set it inside a
`withCString` block that wraps the call — exactly like the existing `language`
handling does. When the prompt is empty, leave the field unset (it defaults to
`nil` in `whisper_full_default_params`), preserving today's behavior.

The current call site in `transcribe(samples:)`:

```swift
let status: Int32 = "en".withCString { english in
    params.language = english
    return padded.withUnsafeBufferPointer { buffer in
        whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
    }
}
```

This is C-API / Metal code that needs a loaded model and real audio to exercise,
so there is **no unit test** — verify with a clean build and the existing test
suite (the default parameter must not disturb current call sites, e.g.
`PipelineCLI`).

**Global constraints:** Swift 6.1, language mode v5. `LocalFlowCore` module.

## Files

- Modify: `Sources/LocalFlowCore/STT/WhisperTranscriber.swift`

## Interfaces

- Consumes: nothing.
- Produces:
  ```swift
  // new signature (default "" keeps existing callers compiling unchanged)
  public func transcribe(samples: [Float], initialPrompt: String = "") throws -> String
  ```

## Steps

- [ ] **Step 1: Change the `transcribe` signature**

In `Sources/LocalFlowCore/STT/WhisperTranscriber.swift`, change the method
declaration from:

```swift
    public func transcribe(samples: [Float]) throws -> String {
```

to:

```swift
    public func transcribe(samples: [Float], initialPrompt: String = "") throws -> String {
```

- [ ] **Step 2: Set `initial_prompt` around the `whisper_full` call**

Replace the existing `let status: Int32 = "en".withCString { … }` block with the
following (it keeps the `language` handling identical and nests the prompt only
when non-empty):

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

        let status: Int32
        if initialPrompt.isEmpty {
            status = run(params)
        } else {
            status = initialPrompt.withCString { prompt in
                var params = params
                params.initial_prompt = prompt
                return run(params)
            }
        }
```

Note: the surrounding code already declares `var params = whisper_full_default_params(...)`
above this block and configures it (`print_progress`, `no_timestamps`,
`n_threads`, etc.). Leave all of that unchanged — this step only replaces the
final `whisper_full` invocation. The `prompt` pointer is valid for the entire
`run(params)` call because `whisper_full` is synchronous and runs inside the
`withCString` closure.

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: build succeeds with no errors.

- [ ] **Step 4: Verify no regression in the existing suite**

Run: `make test`
Expected: the full suite passes (this change adds no tests; it must not break
existing ones — in particular any call site using `transcribe(samples:)` still
compiles thanks to the default argument).

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalFlowCore/STT/WhisperTranscriber.swift
git commit -m "feat: pass initial_prompt to Whisper for vocabulary priming"
```
