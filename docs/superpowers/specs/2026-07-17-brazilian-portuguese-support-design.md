# Design: Brazilian Portuguese support

**Date:** 2026-07-17
**Status:** Approved (pending spec review)

## Overview

Add Brazilian Portuguese (PT-BR) as a second dictation language alongside English.
The user picks the active language manually — a canonical picker in Settings plus a
quick toggle in the menu-bar menu — and every downstream stage (Whisper model
selection, transcription, LLM cleanup) adapts to it. English behaviour is preserved
exactly; Portuguese is additive.

Auto-detection was rejected as the default: dictation is dominated by short utterances
(the `CleanupGate` treats ≤50 chars as the common case), which is where Whisper's
language detection is least reliable, and a mis-detection produces unusable output with
no obvious recovery. Manual selection is predictable and lowest-latency. An "Auto"
language can be added later without reworking this design.

## Goals

- Dictate in Brazilian Portuguese end-to-end: capture → Whisper → sanitize → gate →
  Ollama cleanup → inject.
- Switch between English and Portuguese manually, quickly, without losing per-language
  model choices.
- Preserve English accuracy and behaviour — no regression for existing English users.
- Keep the app fully local (multilingual models come from the same Hugging Face repo).

## Non-goals (YAGNI)

- Automatic per-utterance language detection.
- Languages other than English and PT-BR.
- A tier-based (`fast`/`balanced`/`accurate`) refactor of `WhisperModel`; the concrete
  enum is kept and extended.
- Distinguishing Brazilian from European Portuguese at the STT stage — Whisper's
  language code is a single `pt`. The Brazilian character is applied at the cleanup
  stage via a PT-BR prompt.

## The language concept

A new enum is the single definition of "language", in `Support/DictationLanguage.swift`:

```swift
public enum DictationLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case portugueseBR = "pt"

    public var id: String { rawValue }
    public var whisperCode: String { rawValue }      // "en" / "pt"
    public var displayName: String                    // "English" / "Português (Brasil)"

    public static let `default` = DictationLanguage.english
}
```

`rawValue` doubles as the Whisper language code, so persistence and the C API agree.
Unknown/garbage persisted values fall back to `.default`, matching every other setting.

## Components and changes

### 1. `WhisperModel` (STT/WhisperModel.swift)

Add four multilingual cases from the same whisper.cpp Hugging Face repo:

| case | rawValue | file | approx size |
|------|----------|------|-------------|
| `base` | `base` | `ggml-base.bin` | 148 MB |
| `baseQ5` | `base-q5_1` | `ggml-base-q5_1.bin` | 60 MB |
| `small` | `small` | `ggml-small.bin` | 488 MB |
| `smallQ5` | `small-q5_1` | `ggml-small-q5_1.bin` | 190 MB |

Each model declares the languages it is offered for:

- `.en` models → `[.english]`
- new multilingual `base`/`small` models → `[.portugueseBR]` (multilingual models can
  do English, but `.en` is strictly better for English, so they are not offered there)
- `largeV3Turbo` / `largeV3TurboQ5` → `[.english, .portugueseBR]` (already multilingual;
  they serve both with no new download)

New API:

```swift
public var supportedLanguages: Set<DictationLanguage>
public static func models(for language: DictationLanguage) -> [WhisperModel]  // filtered, ordered
public static func `default`(for language: DictationLanguage) -> WhisperModel  // .english → .smallEN, .portugueseBR → .small
```

`displayName` for the new models mirrors the existing style (fast / balanced / accurate,
with a "quantized" note).

The existing `WhisperModel.default` (`.smallEN`) is retained for back-compat but callers
that know the language use `default(for:)`.

### 2. Per-language model persistence (Support/Settings.swift)

The single `whisperModel` setting becomes language-scoped, stored under keys
`whisperModel.en` and `whisperModel.pt`.

```swift
public var language: DictationLanguage { get set }               // default .english

public func whisperModel(for language: DictationLanguage) -> WhisperModel
public func setWhisperModel(_ model: WhisperModel, for language: DictationLanguage)

// Convenience for the active language; used by existing call sites.
public var whisperModel: WhisperModel { get set }                // reads/writes the active language's slot
```

- Reading a language's model: persisted value if valid **and** supported for that
  language, else `WhisperModel.default(for: language)`.
- **Migration:** on first read, if `whisperModel.en` is absent but the legacy flat
  `whisperModel` key is present, seed `whisperModel.en` from it so the user keeps their
  English selection. The legacy key is then ignored.

### 3. `WhisperTranscriber` (STT/WhisperTranscriber.swift)

`transcribe` gains a language parameter; the hardcoded `"en"` becomes the language's
Whisper code:

```swift
public func transcribe(samples: [Float], language: DictationLanguage = .english) throws -> String
```

`params.translate` stays `false` — we transcribe in the source language and never
translate to English. The default argument keeps existing tests/call sites compiling.

### 4. `CleanupGate` (Core/CleanupGate.swift)

The gate's "does this transcript need cleanup?" heuristic becomes language-aware:

```swift
public static func shouldClean(transcript: String, cleanupEnabled: Bool, language: DictationLanguage) -> Bool
static func needsCleanup(_ transcript: String, language: DictationLanguage) -> Bool
```

- English: existing filler pattern, unchanged.
- Portuguese: a filler pattern targeting hesitation forms and discourse crutches —
  `éé`/`ééé`, `ãã`, `hã`, `tipo`, `né`, `então`, `sabe`. Deliberately **excludes** bare
  `é` (the verb "to be"; matching it would route nearly every PT transcript to the LLM).
- The stutter pattern and the capitalization / terminal-punctuation checks are
  language-agnostic and shared unchanged.

The gate only decides *whether to run* cleanup, so an over-eager PT match costs latency,
never correctness.

### 5. `OllamaCleaner` (LLM/OllamaCleaner.swift)

Prompt selection becomes language-aware:

```swift
static func promptTemplate(for language: DictationLanguage) -> String
public static func makeRequest(transcript: String, config: OllamaConfig, language: DictationLanguage) throws -> URLRequest
public static func clean(transcript: String, config: OllamaConfig, language: DictationLanguage) async -> CleanupOutcome
```

- English template: unchanged content, plus an explicit **"keep the input language, do
  not translate"** line (harmless for English, protects against accidental translation).
- Portuguese template: written in PT-BR, with the same cleanup rules and PT filler
  examples (é, tipo, né, então, sabe), and the same never-translate instruction.
- `postProcess` gains PT preamble patterns ("aqui está…", "segue…", "versão
  corrigida…") alongside the existing English ones, so a chatty PT model's preamble line
  is stripped. Language-agnostic (both pattern sets always run); low-risk.

`warmUp` is prompt-less and needs no language.

### 6. `DictationController` (Core/DictationController.swift)

Reads `settings.language` and threads it through `process(samples:)` into the
transcriber, the gate, and the cleaner. `preloadModelIfAvailable` / `ensureModelReady`
already use `settings.whisperModel`, which now resolves per-language, so model preload
follows the active language automatically. No state-machine changes.

### 7. `StatusItemController` (UI/StatusItemController.swift) — menu toggle

The menu (rebuilt on each open) gains a "Language" section above "Settings…": one
checkmarked item per `DictationLanguage`. Selecting a language sets `settings.language`
and calls `controller.start()` (re-preload the right model, re-warm Ollama). The
existing "model not downloaded" menu line already reads `settings.whisperModel`, so it
correctly reflects the active language after a toggle.

### 8. `SettingsView` (UI/SettingsView.swift) — canonical picker

A "Language" picker is added at the top of the "Speech recognition" section, bound to
`settings.language` (pipeline-restarting). The existing "Whisper model" picker is
changed to iterate `WhisperModel.models(for: settings.language)` instead of `allCases`,
so it only shows models valid for the active language. Both restart the pipeline via the
existing `binding(...)` mechanism.

### 9. `PipelineCLI` (Core/PipelineCLI.swift)

Add `--language en|pt` (default `en`), parsed like the other flags and validated against
`DictationLanguage(rawValue:)`. It is threaded into transcribe, gate, and cleanup. When
`--language pt` is supplied without `--model`, the model defaults to
`WhisperModel.default(for: .portugueseBR)` (i.e. `small`). Usage/help text updated.

## Data flow

```
hotkey → mic → AudioRecorder
      → WhisperTranscriber.transcribe(samples, language)      // language.whisperCode, translate=false
      → TranscriptSanitizer.sanitize                          // unchanged, language-agnostic
      → CleanupGate.shouldClean(…, language)                  // language-specific filler heuristic
      → [if yes] OllamaCleaner.clean(…, language)             // language-specific prompt, never translate
      → TextInjector.inject                                   // unchanged
```

`settings.language` is the single source of truth, read once per dictation in
`DictationController.process`, and controls model selection, the Whisper code, the gate
pattern, and the prompt.

## Error handling

Unchanged. Cleanup remains best-effort: an unreachable/slow/erroring Ollama falls back to
the raw (sanitized) transcript with a non-blocking warning, in both languages. A missing
Portuguese model triggers the same download flow and menu/Settings prompts as a missing
English model (`ModelManager` is model-agnostic).

## Testing (test-first, Swift Testing, in `LocalFlowCore`)

- **`DictationLanguage`**: `whisperCode`, `displayName`, rawValue round-trip, `.default`.
- **`WhisperModel`**: `models(for:)` returns the right filtered/ordered set per language;
  `default(for:)` mapping; new cases' `fileName` / `downloadURL`; turbo appears for both
  languages.
- **`Settings`**: per-language get/set isolation (setting PT doesn't disturb EN);
  fallback to `default(for:)` on missing/invalid/unsupported persisted value; migration
  from the legacy flat `whisperModel` key into `whisperModel.en`; `language`
  default/garbage-fallback.
- **`CleanupGate`**: PT filler forms trigger; bare `é` does **not** trigger; PT
  punctuation/capitalization heuristics fire; English behaviour byte-for-byte unchanged.
- **`OllamaCleaner`**: `makeRequest` embeds the PT template for `.portugueseBR` and it
  contains the never-translate instruction; English template unchanged; `postProcess`
  strips a PT preamble line.

## Documentation

- `CLAUDE.md`: replace "English-only by design" with "English + Brazilian Portuguese";
  update the `params.language` note (no longer hardcoded `en`); document `--language` in
  the headless-pipeline example; update the "Known constraints" section (drop
  English-only, note PT-BR is `pt` at STT and PT-BR only at cleanup).
```
