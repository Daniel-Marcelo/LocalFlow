# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LocalFlow is a fully-local macOS voice dictation menu-bar app (Apple Silicon, macOS 14+).
The loop is: hold a hotkey → mic capture → whisper.cpp (Metal) transcription → optional
Ollama LLM cleanup → inject text at the cursor. Nothing leaves the machine except
`localhost:11434` (Ollama) and the one-time Whisper model download from Hugging Face.

## Commands

```sh
make app     # fetch whisper.cpp, build, assemble LocalFlow.app in repo root
make build   # swift build (release) + precompile Metal shaders if toolchain present
make run     # build + launch the app
make test    # unit tests (Swift Testing)
make clean   # remove .build and LocalFlow.app
```

- **Run one test:** `./scripts/test.sh --filter TranscriptSanitizerTests` (forwards args to
  `swift test`). Always go through `make test` / `scripts/test.sh`, not bare `swift test` —
  under bare Command Line Tools the script injects the framework and macro-plugin paths that
  Swift Testing needs; plain `swift test` fails to link there.
- **Headless pipeline (no permissions, no mic):** exercises audio → Whisper → sanitize → gate
  → Ollama end to end from a file. Best way to test STT/LLM changes.
  ```sh
  .build/release/LocalFlow --transcribe speech.aiff [--language en|pt] [--model base.en] [--no-cleanup] [--ollama-model gemma3:4b]
  say -o speech.aiff "some test sentence"   # generate test audio
  ```
  If built *without* the full Xcode Metal toolchain, prefix with
  `GGML_METAL_PATH_RESOURCES=Vendor/metal-resources` to keep GPU inference.
- **Stable Accessibility grant across rebuilds:** the default build is ad-hoc signed, and
  ad-hoc signatures change every build, so macOS drops the app from the Accessibility list on
  rebuild. Sign with a real identity to avoid re-granting:
  `make app CODESIGN_IDENTITY="Apple Development: you@example.com (TEAMID)"`.

## Architecture

SwiftPM package, Swift language mode v5 (tools 6.1). Three targets:

- **`LocalFlowCore`** (`Sources/LocalFlowCore/`) — the library holding *all* logic. Everything
  testable lives here; the pure-logic pieces were built test-first and have matching tests
  (sanitizer, cleanup gate, Ollama client, settings, model catalog, hotkey choices, audio level).
  Prefer adding logic here over the executable target.
- **`LocalFlow`** (executable) — note the path mismatch: this target's sources are in
  `Sources/LocalFlowApp/`, and its `main.swift` is a two-line shim into `AppMain.run()`.
- **`LocalFlowTests`** (`Tests/LocalFlowTests/`) — Swift Testing.

### The pipeline

`DictationController` (`Core/DictationController.swift`) is the central orchestrator — a
`@MainActor ObservableObject` driving a state machine:
`idle → recording → transcribing → cleaning → idle` (plus a transient `error` that auto-resets
to idle after 4 s). Understanding this file explains most of the app. Key invariants:

- Transcription runs on a dedicated serial `whisperQueue` because whisper contexts are **not
  thread-safe**; results hop back to `@MainActor` for cleanup/injection.
- `TranscriptSanitizer` always runs on the raw Whisper output first. Then `CleanupGate` decides
  whether to invoke the LLM at all: it **skips** cleanup for transcripts ≤ 50 chars or ones that
  already look clean (no filler words / stutters, proper capitalization and terminal
  punctuation). This is a deliberate latency optimization — the LLM is the slowest stage.
- `OllamaCleaner` is best-effort and **never blocks dictation**: on unreachable/timeout/error it
  returns the raw transcript with a non-blocking `warning` surfaced in the menu. The app is fully
  functional with Ollama down.

### Entry points

`AppMain.run()` forks on argv: `--transcribe`/`--help` runs `PipelineCLI` under `dispatchMain()`
(headless); otherwise it starts `NSApplication` with `AppDelegate`. `AppDelegate` wires the
pieces together — `Settings`, `DictationController`, `StatusItemController` (menu-bar glyph),
`SettingsWindowController`, `HUDController` (on-screen waveform). It's a menu-bar-only app
(`.accessory` activation policy / `LSUIElement`), never a Dock icon.

### Permissions

Accessibility is the load-bearing grant — it gates **both** the global hotkey event tap and the
text injection. macOS posts no notification when it's granted, so `AppDelegate` **polls** every
2 s and brings the event tap up without a relaunch. Microphone is requested lazily on first
dictation. `Settings` persists to `UserDefaults`; unknown/garbage values fall back to defaults.

## whisper.cpp & Metal (the subtle part)

whisper.cpp is **pinned at v1.7.2** — the last tag shipping a SwiftPM manifest with Metal
enabled. It is vendored as a **local path dependency** (`Vendor/whisper.cpp`, gitignored) rather
than a remote package, because its manifest uses `unsafeFlags`, which SwiftPM forbids in remote
deps. `scripts/fetch-whisper.sh` clones the tag and is run automatically by every `make` target.

Metal shaders need special handling because pure-SwiftPM builds can't compile `.metal` files and
whisper's resource lookup can't find its bundle from inside a packaged `.app`. The scheme:

1. `fetch-whisper.sh` generates a **self-contained** `Vendor/metal-resources/ggml-metal.metal`
   (with `ggml-common.h` inlined, since the runtime Metal compiler can't resolve the `#include`).
2. **Packaged app:** the Makefile copies that file into `Contents/Resources/`, and `AppMain`
   points `GGML_METAL_PATH_RESOURCES` at it so ggml JIT-compiles the shaders once at model
   preload.
3. **Dev / CLI runs from `.build`:** if the full Xcode Metal toolchain is present, `make build`
   precompiles `default.metallib` into the SwiftPM resource bundle, which loads with no JIT.
4. If neither resource is found, whisper **silently falls back to CPU** (still works, just
   slower — watch for `ggml_metal_init: error` on stderr).

Models (`WhisperModel`) download on demand from Hugging Face into
`~/Library/Application Support/LocalFlow/models/`. English uses the English-only (`.en`)
models; Brazilian Portuguese uses the multilingual variants (`WhisperModel.models(for:)`
picks the set for the active language). The `large-v3-turbo` models are multilingual and
serve both.

## Known constraints

- Secure input fields (password boxes) block synthetic keyboard events at the OS level —
  dictation into them is impossible by design.
- Languages: English and Brazilian Portuguese. The active language is selected manually in
  Settings or the menu bar. PT-BR uses Whisper's `pt` language code (no distinction from
  European Portuguese at the STT stage); the Brazilian character is applied by the PT-BR
  cleanup prompt.
