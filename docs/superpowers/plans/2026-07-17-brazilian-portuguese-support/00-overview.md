# Brazilian Portuguese Support — Implementation Plan (Overview)

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Each task
> lives in its own file in this directory and is fully self-contained — an
> implementer needs only that one file plus the repository. Execute the tasks
> **in numeric order** (each consumes types the previous one produced). Steps
> use checkbox (`- [ ]`) syntax.

**Goal:** Add Brazilian Portuguese as a second dictation language alongside
English — the user picks the active language manually, and every downstream
stage (Whisper model selection, transcription, LLM cleanup) adapts to it.
English behaviour is preserved exactly; Portuguese is additive.

**Architecture:** A new `DictationLanguage` enum is the single definition of
"language". It controls: which Whisper models are offered, the language code
passed to whisper.cpp, the filler-word pattern in `CleanupGate`, and the
prompt template in `OllamaCleaner`. `Settings.language` is the single source
of truth, with per-language model slots (`whisperModel.en` / `whisperModel.pt`).
The user picks the language from Settings or a quick toggle in the menu bar.

**Tech Stack:** Swift 6.1 / SwiftPM (language mode v5), SwiftUI, Foundation
`NSRegularExpression`, whisper.cpp C API, Ollama HTTP.

**Design spec:** `docs/superpowers/specs/2026-07-17-brazilian-portuguese-support-design.md`

## Task Order & Dependencies

| # | File | Produces | Depends on |
| - | ---- | -------- | ---------- |
| 1 | `01-dictation-language.md` | `DictationLanguage` enum | — |
| 2 | `02-whisper-model-multilingual.md` | Multilingual `WhisperModel` cases, `models(for:)`, `default(for:)` | 1 |
| 3 | `03-settings-language.md` | `Settings.language`, per-language model get/set, migration | 1, 2 |
| 4 | `04-whisper-transcriber-language.md` | `WhisperTranscriber.transcribe(samples:language:)` | 1 |
| 5 | `05-cleanup-gate-language.md` | Language-aware `CleanupGate.shouldClean` | 1 |
| 6 | `06-ollama-cleaner-language.md` | Language-aware `OllamaCleaner.clean` with PT-BR prompt | 1 |
| 7 | `07-pipeline-integration.md` | `DictationController` + `PipelineCLI` wiring | 1–6 |
| 8 | `08-ui-language-controls.md` | Menu toggle + Settings picker, model picker filter | 1–3 |

Execute strictly in numeric order — each task ends with a compiling,
committable deliverable. Tasks 4, 5, and 6 are independent of each other (all
only depend on Task 1) and could be done in parallel.

## Global Constraints

Every task's requirements implicitly include these:

- **Toolchain:** Swift 6.1, SwiftPM language mode **v5** (set per target in
  `Package.swift`). Target platform macOS 14+, Apple Silicon.
- **Module:** all source lives in the `LocalFlowCore` target under
  `Sources/LocalFlowCore/`. SwiftPM auto-discovers sources, so new files in
  existing subdirectories need **no** `Package.swift` change.
- **Tests:** live in `Tests/LocalFlowTests/` and use **Swift Testing**
  (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`) — not XCTest.
  Run them via `./scripts/test.sh --filter <SuiteName>` or `make test` — never
  bare `swift test` (under bare Command Line Tools the script injects framework
  and macro-plugin paths that plain `swift test` lacks).
- **Compile checks** use `swift build` (debug is fine; the Metal shader is a
  runtime resource, not needed to compile).
- **English regression:** existing English cleanup **behaviour and rules** are
  preserved and every existing English test must stay green. All new parameters
  default to `.english` or English-equivalent values so existing call sites
  compile unchanged. The one intentional change to English output is the
  approved defensive "do not translate — keep the input language" clause added
  to the English cleanup instruction (Task 6) — this is by design, not a
  regression.
- **No auto-detection:** language is always explicit and user-selected.
  Auto-detect is a YAGNI.
- **Model separation:** `.en` models are only offered for English. Multilingual
  `base`/`small` are only offered for Portuguese. `largeV3Turbo` variants are
  offered for both.
- **Never translate:** `params.translate` stays `false`. Whisper transcribes in
  the source language; translation is never used.
- **Robustness contract:** Ollama cleanup remains best-effort and never blocks
  dictation in either language. A missing Portuguese model triggers the same
  download flow as a missing English model.
- **Preserve the custom-vocabulary feature:** the pipeline already threads a
  vocabulary priming prompt and preserve-list through STT and cleanup —
  `WhisperTranscriber.transcribe(samples:initialPrompt:)`,
  `OllamaCleaner.makeRequest(...preserveList:)` /
  `clean(...preserveList:)`, and `DictationController` building a `Vocabulary`
  and passing `primingPrompt` / `preserveList`. Every language change is
  **additive** to this wiring — the `language` argument is added *alongside*
  `initialPrompt` / `preserveList`, never replacing them. Do not revert
  `OllamaCleaner` to a single `%@` template.
