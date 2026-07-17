# Custom Vocabulary — Design

**Date:** 2026-07-17
**Status:** Approved

## Summary

Whisper reliably mangles proper nouns, jargon, and acronyms it hasn't "heard"
("Kubernetes", a coworker's name, a product name), and it mangles some of them
the *same way every time* ("clod code" for "Claude Code"). This feature lets the
user maintain a personal vocabulary that fixes both failure modes through two
complementary mechanisms, driven from **one combined list**:

- **Priming** — the user's terms are fed to Whisper as `initial_prompt`, biasing
  the decoder toward recognizing them. Soft / probabilistic.
- **Replacement** — deterministic `variant → canonical` find-and-replace applied
  after transcription. Hard / exact.

The list is edited through a table in the Settings window. The feature is a
**no-op with ~zero cost when the list is empty** (the default), and nothing in
it can block or break dictation — the same robustness contract the Ollama
cleanup stage already honors.

## Goals

- One unified list where each entry is a canonical term plus optional variants,
  driving both priming and replacement.
- Priming biases Whisper via `initial_prompt`, capped to Whisper's token budget.
- Replacement deterministically fixes known mishearings in the final output,
  whether or not the LLM cleanup stage ran.
- Vocabulary terms are protected from the LLM cleanup stage (the LLM is told not
  to alter them), guarding against *novel* manglings replacement can't know about.
- Edited via a Settings table; persisted in `UserDefaults`; picked up on the
  next dictation with no restart.
- Zero behavior change for existing users: an empty list changes nothing.

## Non-Goals (YAGNI)

- Per-app or per-hotkey vocabulary variations.
- Import/export, sync, or sharing of vocabularies.
- User-authored regular expressions or wildcard rules (variants are literal).
- Per-term enable/disable, categories, or tags.
- Multilingual priming/replacement (the app is English-only by design).
- Wiring vocabulary into the headless `--transcribe` CLI (the pure logic is
  tested directly, so the CLI is not needed for coverage).

## Data Model

### `VocabularyEntry`

A value type: `{ term: String, variants: [String] }`.

- `term` — the canonical spelling, authoritative for both mechanisms.
- `variants` — zero or more literal strings Whisper is known to emit for this
  term. An entry with no variants is **priming-only**.

`Codable`, persisted as a JSON array under a single `UserDefaults` key.

### `Vocabulary`

A value type wrapping `[VocabularyEntry]` that owns all derivation and is the
pure, unit-tested core:

- **Normalization** (applied once at construction): trim whitespace on terms and
  variants; drop rows with an empty `term`; drop empty variants; drop a variant
  equal (case-insensitively) to its own term (a no-op); dedupe.
- **`primingPrompt: String`** — the canonical terms joined with `", "`, in list
  order, truncated to the priming budget (below). Empty when there are no terms.
- **`droppedFromPriming: Int`** — how many terms did not fit the priming budget
  (for the editor's note). Dropped terms still function as replacements if they
  have variants.
- **`replacements`** — the ordered, escaped match rules (below). Empty when no
  entry has variants.
- **`preserveList: String`** — canonical terms for the cleanup-protection prompt
  line, capped (below). Empty when there are no terms.

## Mechanism 1 — Priming (`initial_prompt`)

`WhisperTranscriber.transcribe(samples:)` gains an `initialPrompt: String`
parameter. When non-empty it is set on `whisper_full_params.initial_prompt`
(confirmed present in the vendored `whisper.h:516`, capped by whisper at
`n_text_ctx()/2` ≈ 224 tokens). When empty, the field is left unset — identical
to today's behavior.

The C string must outlive the `whisper_full` call: `initial_prompt` is bound
inside a `withCString` block wrapping the existing `"en".withCString` /
`whisper_full` call (nested `withCString` is fine).

**Budget.** We cannot count Whisper BPE tokens without tokenizing, and whisper
*silently* truncates past ~224 tokens, so the cap is a UX nicety, not a
correctness requirement. `primingPrompt` is capped at a **conservative 500
characters** — chosen to stay safely under 224 tokens even for subword-heavy
proper nouns. Terms are included in list order until the next term would exceed
the cap; the remainder increment `droppedFromPriming`.

## Mechanism 2 — Replacement

Applied as the **final pass before injection**, unconditionally — so it fixes
known mishearings on both the cleaned path and the gate-skipped raw path.

**Matching semantics:**

- Build **one** combined case-insensitive `NSRegularExpression`: an alternation
  of all variants across all entries, each escaped with
  `NSRegularExpression.escapedPattern(for:)`, ordered **longest-first** so
  overlapping variants (`"code"` vs `"clod code"`) prefer the longer match.
- The alternation is wrapped in `(?<!\w) … (?!\w)` boundary lookarounds so a
  variant never matches inside a larger word (`"to"` must not fire inside
  `"today"`), and so multi-word phrase variants still match.
- Each match is replaced with the canonical `term` of whichever variant matched,
  looked up case-insensitively. Because it is a single pass over the original
  text, one rule's output can never be re-matched by another rule (no cascade).
- Output uses the canonical term's **exact casing** — the spelling is
  authoritative (`"Kubernetes"` always has a capital K), independent of the
  surrounding sentence's casing.

**Conflicts.** If the same variant string maps to two different terms across
rows, the first entry in list order wins (documented behavior).

**Empty case.** No entry has variants → `replacements` is empty → the pass is
skipped and the text passes through unchanged.

## Pipeline Integration

Plugs into [`DictationController`](../../../Sources/LocalFlowCore/Core/DictationController.swift):

```
recorder ─▶ whisper.transcribe(samples, initialPrompt)      ← PRIMING
         ─▶ TranscriptSanitizer.sanitize
         ─▶ cleanAndInject:
              if gate.shouldClean → OllamaCleaner.clean(…, preserveList)   ← PROTECT
              finalText = vocabulary.applyReplacements(finalText)          ← REPLACEMENT (always)
              TextInjector.inject(finalText)
```

`process(samples:)` already snapshots settings values before hopping to the
whisper queue; it additionally snapshots the current `Vocabulary`, derives
`primingPrompt`, and passes it into `transcribe`. The `Vocabulary` (for
`replacements` and `preserveList`) is carried through to `cleanAndInject` on the
main actor. Because `process()` reads settings fresh each dictation, list edits
take effect on the **next** dictation with no reload wiring.

### Cleanup protection

`OllamaCleaner` gains a `preserveList` input (empty string = omit). When
non-empty, the prompt template ([`OllamaCleaner.swift:33`](../../../Sources/LocalFlowCore/LLM/OllamaCleaner.swift)) gains one line:

> `Preserve these terms exactly as written; do not change their spelling: <preserveList>.`

`preserveList` is capped at **1000 characters** (gemma3:4b has ample context,
but the prompt is kept lean); terms are included in list order until the cap.

## Settings UI + Persistence

- **`Settings.swift` (edit):** a `vocabulary: [VocabularyEntry]` property
  JSON-encoded into `UserDefaults` under one key, following the existing
  getter/setter + `changeCounter` pattern. Unreadable/garbage data decodes to an
  empty list — consistent with the app's "unknown values fall back to defaults"
  rule.
- **`SettingsView.swift` (edit):** one new row — **"Vocabulary — N terms ·
  [Edit…]"** — that presents the editor as a sheet, keeping the main panel
  compact.
- **`VocabularyEditor.swift` (new):** a `List` of rows, each with two
  `TextField`s (**Term**, **Also heard as** — comma-separated variants), a **＋
  Add** button, and per-row delete. A `List` of rows is chosen over SwiftUI
  `Table` because inline-editable `Table` cells on macOS are awkward, and this
  matches the lightweight style of the rest of Settings. The editor shows a
  gentle note when `droppedFromPriming > 0` ("Some terms exceed Whisper's
  priming limit and won't bias recognition; corrections still apply.").

## Edge Cases & Error Handling

The feature degrades to a **no-op** and adds ~zero cost when the list is empty.
Nothing here throws in a way that breaks dictation: priming sets a param,
replacement is pure string work, a malformed row is skipped (not fatal). Same
spirit as "Ollama cleanup never blocks dictation."

- Empty vocabulary → `initial_prompt` unset, replacement skipped, no preserve
  line.
- Priming overflow → excess terms dropped from priming only; still work as
  replacements; editor notes the count.
- Variant regex metacharacters (`.`, `(`, …) are escaped before pattern build.
- Single-pass replacement prevents cascades.
- Incomplete/duplicate rows trimmed, dropped, deduped; self-referential variant
  ignored; conflicting variant resolves first-wins.
- `preserveList` capped and omitted when empty.

## Testing Strategy

Mirrors the existing test-first pure-logic pieces (sanitizer, gate, Ollama,
settings all have tests).

- **`VocabularyTests` (new, TDD):**
  - Normalization: trims, drops empty terms/variants, dedupes, ignores
    self-referential variant.
  - Priming: joins canonical terms; respects the 500-char budget; reports
    `droppedFromPriming`; empty vocab → empty prompt.
  - Replacement: case-insensitive match with canonical-cased output; word and
    phrase boundaries (no substring-in-word); longest-variant-first; regex
    metacharacter escaping; single-pass / no-cascade; first-wins conflict
    resolution; empty vocab → identity.
  - `preserveList`: joined canonical terms, capped, empty when no terms.
- **`SettingsTests` (edit):** `vocabulary` round-trips through `UserDefaults`;
  undecodable data → empty list.
- **`OllamaCleanerTests` (edit):** `makeRequest` includes the preserve line when
  `preserveList` is non-empty, omits it when empty.
- **AppKit/SwiftUI wiring (compile + manual):** `VocabularyEditor`,
  `SettingsView`, and the `DictationController`/`WhisperTranscriber`/
  `OllamaCleaner` signature changes are verified with `swift build`, the headless
  `--transcribe` pipeline, and a manual run.

## Files Touched

- Create: `Sources/LocalFlowCore/Vocab/Vocabulary.swift`
  (`VocabularyEntry`, `Vocabulary`)
- Create: `Sources/LocalFlowCore/UI/VocabularyEditor.swift`
- Create: `Tests/LocalFlowTests/VocabularyTests.swift`
- Modify: `Sources/LocalFlowCore/Support/Settings.swift`
- Modify: `Sources/LocalFlowCore/STT/WhisperTranscriber.swift`
- Modify: `Sources/LocalFlowCore/LLM/OllamaCleaner.swift`
- Modify: `Sources/LocalFlowCore/Core/DictationController.swift`
- Modify: `Sources/LocalFlowCore/UI/SettingsView.swift`
- Modify: `Tests/LocalFlowTests/SettingsTests.swift`
- Modify: `Tests/LocalFlowTests/OllamaCleanerTests.swift`
