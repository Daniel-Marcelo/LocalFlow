# Custom Vocabulary — Implementation Plan (Overview)

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Each task
> lives in its own file in this directory and is fully self-contained — an
> implementer needs only that one file plus the repository. Execute the tasks
> **in numeric order** (each consumes types the previous one produced). Steps
> use checkbox (`- [ ]`) syntax.

**Goal:** Let the user maintain a personal vocabulary that both biases Whisper
toward their terms (priming) and deterministically fixes terms it consistently
mishears (replacement), edited from a table in Settings.

**Architecture:** One combined list of `{ term, variants }` entries drives two
mechanisms. A pure `Vocabulary` value type derives a budgeted `initial_prompt`
string (priming) and a single-pass variant→canonical replacement (applied as the
final step before injection, so it covers the gate-skipped path too). Vocabulary
terms are also passed to the Ollama cleanup prompt as "preserve exactly". The
feature is a **no-op with ~zero cost when the list is empty**.

**Tech Stack:** Swift 6.1 / SwiftPM (language mode v5), SwiftUI, Foundation
`NSRegularExpression`, whisper.cpp C API, Ollama HTTP.

**Design spec:** `docs/superpowers/specs/2026-07-17-custom-vocabulary-design.md`
(background reference; each task file embeds what it needs).

## Task Order & Dependencies

| # | File | Produces | Depends on |
| - | ---- | -------- | ---------- |
| 1 | `01-vocabulary-model.md` | `VocabularyEntry`, `Vocabulary` (`primingPrompt`, `droppedFromPriming`, `preserveList`, `applyReplacements(_:)`) | — |
| 2 | `02-settings-persistence.md` | `Settings.vocabulary: [VocabularyEntry]` | 1 |
| 3 | `03-whisper-priming.md` | `WhisperTranscriber.transcribe(samples:initialPrompt:)` | — |
| 4 | `04-ollama-preserve-terms.md` | `OllamaCleaner.makeRequest/clean(…, preserveList:)` | — |
| 5 | `05-pipeline-integration.md` | `DictationController` wiring priming + replacement + preserve | 1, 2, 3, 4 |
| 6 | `06-settings-editor-ui.md` | `VocabularyEditor` sheet + Settings row | 1, 2 |

Execute strictly in numeric order — each task ends with a compiling,
committable deliverable. Tasks 1, 3, and 4 are independent and could be done in
any order; they are numbered to keep the integration (Task 5) reading top-down.

## Global Constraints

Every task's requirements implicitly include these:

- **Toolchain:** Swift 6.1, SwiftPM language mode **v5** (set per target in
  `Package.swift`). Target platform macOS 14+, Apple Silicon.
- **Module:** all source lives in the `LocalFlowCore` target under
  `Sources/LocalFlowCore/`. SwiftPM auto-discovers sources, so the new
  `Sources/LocalFlowCore/Vocab/` directory needs **no** `Package.swift` change.
- **Tests:** live in `Tests/LocalFlowTests/` and use **Swift Testing**
  (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`) — not XCTest.
  Run them via `./scripts/test.sh --filter <SuiteName>` or `make test` — never
  bare `swift test` (under bare Command Line Tools the script injects framework
  and macro-plugin paths that plain `swift test` lacks).
- **Compile checks** use `swift build` (debug is fine; the Metal shader is a
  runtime resource, not needed to compile).
- **Robustness contract:** the feature is a **no-op** when the vocabulary is
  empty, and nothing in it may throw in a way that blocks dictation — priming
  just sets a param, replacement is pure string work, a malformed row is
  skipped. Same spirit as "Ollama cleanup never blocks dictation".
- **Budgets (verbatim from spec):** priming prompt capped at **500** characters;
  cleanup preserve-list capped at **1000** characters.
- **Persistence is raw:** `Settings.vocabulary` stores entries exactly as edited
  (un-normalized). Normalization (trim/dedupe/drop-empty/self-ref) happens only
  inside the `Vocabulary` value at derivation time.
- **`VocabularyEntry` pattern:** `Codable, Equatable, Identifiable` with a
  `UUID id` (stable identity for the SwiftUI list; round-trips through Codable).
