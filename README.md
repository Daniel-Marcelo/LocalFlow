# LocalFlow

Fully-local, offline voice dictation for macOS. Hold a key, speak, release —
clean punctuated text appears at your cursor in whatever app you're using.
In the spirit of Wispr Flow, but nothing ever leaves your machine.

```
Hold Right ⌥  →  mic capture  →  whisper.cpp (Metal)  →  Ollama cleanup  →  text at cursor
```

- **Speech-to-text:** [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
  with the Metal backend, on-device.
- **Cleanup:** a local LLM via [Ollama](https://ollama.com) (default
  `gemma3:4b`) removes filler words ("um", "you know"), false starts, and
  fixes punctuation. Optional — the app works fine with Ollama down.
- **Injection:** pasted at the cursor (your clipboard is saved and restored),
  or typed as keystrokes for paste-blocking fields.
- **Privacy:** no network calls except `localhost:11434` (Ollama) and the
  one-time Whisper model download from Hugging Face.

Requires macOS 14+ on Apple Silicon.

## Build

Needs only the Xcode **Command Line Tools** (`xcode-select --install`).
With full Xcode installed (plus its Metal toolchain:
`xcodebuild -downloadComponent MetalToolchain`) the build additionally
precompiles the GPU shaders, which dev/CLI runs load directly.

```sh
make app        # fetches whisper.cpp v1.7.2, builds, assembles LocalFlow.app
make run        # build + launch
make test       # unit tests
```

`make app` produces `LocalFlow.app` in the repo root. Move it to
/Applications if you like (re-grant permissions if you move it after
granting).

## First run

1. **Launch** LocalFlow — a mic icon appears in the menu bar (no Dock icon).
2. **Whisper model download**: on first launch the Settings window opens and
   fetches the default model, `ggml-small.en` (466 MB), into
   `~/Library/Application Support/LocalFlow/models/` with a progress bar.
   Everything after this download is offline.
3. **Accessibility permission**: macOS will prompt ("LocalFlow would like to
   control this computer"). Grant it in System Settings → Privacy & Security →
   Accessibility. This gates **both** the global hotkey listener and the text
   injection; the menu-bar icon shows ⚠️ until it's granted. No relaunch
   needed — the app detects the grant within a couple of seconds.
4. **Microphone permission**: prompted on your first dictation.
5. If you use LLM cleanup (on by default), have Ollama running with the model
   pulled:

   ```sh
   ollama pull gemma3:4b
   ```

## Use

Hold **Right Option ⌥**, speak, release. The menu-bar icon cycles
idle → 🎤 listening → 〰 transcribing → ✨ cleaning, and a small HUD near the
bottom of the screen mirrors it (optional). Text lands at your cursor.

Settings (menu-bar icon → Settings…):

| Setting | Options |
| --- | --- |
| Activation key | Right/Left ⌥, Right ⌘, Right ⌃, F13–F15 |
| Mode | Hold-to-talk, or press-to-toggle |
| Whisper model | `base.en` (fastest) · `small.en` (default) · `large-v3-turbo` (most accurate), each also as a smaller/faster quantized variant |
| LLM cleanup | On/off, Ollama model name, connection test |
| Injection | Paste (default) or type |
| Feedback | HUD on/off, sound cues on/off |

To keep latency down, LLM cleanup is skipped when it wouldn't help:
dictations of ≤ 50 characters, and transcripts that already read clean (no
filler words or stutters, proper capitalization and punctuation) are injected
directly. If Ollama is unreachable, times out, or errors, the raw Whisper
transcript is injected and a ⚠️ warning shows in the menu — dictation never
blocks on the LLM.

## Development notes

- **Project layout**: SwiftPM package. `LocalFlowCore` (library, all logic) +
  `LocalFlow` (thin executable) + `LocalFlowTests` (Swift Testing).
  whisper.cpp is pinned at **v1.7.2** — the last tag with a SwiftPM manifest
  (Metal enabled) — vendored by `scripts/fetch-whisper.sh` as a local path
  dependency (required because its manifest uses `unsafeFlags`).
- **Metal**: pure-SwiftPM builds can't compile `.metal` files, and whisper's
  SwiftPM resource lookup can't find its bundle from inside a packaged .app,
  so LocalFlow handles shaders itself. The fetch script generates a
  self-contained `ggml-metal.metal` (with `ggml-common.h` inlined). The app
  ships it in Resources and points `GGML_METAL_PATH_RESOURCES` there at
  startup, so ggml JIT-compiles it once during model preload. When the Metal
  toolchain is available, `make build` also precompiles `default.metallib`
  into the SwiftPM resource bundle, which dev/CLI runs load directly with no
  JIT. If neither resource exists, whisper silently falls back to CPU — still
  fast, just slower (watch for `ggml_metal_init: error` on stderr).
- **Headless pipeline testing** (no permissions needed):

  ```sh
  .build/release/LocalFlow --transcribe speech.aiff \
    [--model base.en] [--no-cleanup] [--ollama-model gemma3:4b]
  ```

  (If built without the Metal toolchain, prefix with
  `GGML_METAL_PATH_RESOURCES=Vendor/metal-resources` to get GPU inference.)

  Handy with `say -o speech.aiff "some test sentence"`.
- **Tests**: `make test` (wraps `swift test` with the framework/plugin paths
  Swift Testing needs under bare Command Line Tools).
- **Accessibility grants and rebuilds**: the default build is ad-hoc signed,
  and every rebuild changes an ad-hoc signature, so macOS may drop the app
  from the Accessibility list after a rebuild — remove and re-add it
  (System Settings → Accessibility), or toggle it off/on. For a stable
  signature across builds, sign with a real identity:

  ```sh
  make app CODESIGN_IDENTITY="Apple Development: you@example.com (TEAMID)"
  ```

## Known limitations

- **Secure input fields** (password boxes, some terminal password prompts)
  block synthetic keyboard events at the OS level. Dictation into those is
  not possible by design; the injected text simply won't appear.
- English-only (`.en` Whisper models, cleanup prompt written for English).
- The clipboard is briefly (≈0.6 s) occupied by the dictated text in paste
  mode before being restored.
- In toggle mode, a press while a previous dictation is still transcribing is
  ignored (the toggle can then be one press out of sync).
