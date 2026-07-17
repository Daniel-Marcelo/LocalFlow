# LocalFlow

Fully-local voice dictation for macOS. Hold a key, speak, release — text appears at your cursor. Nothing leaves your machine.

Requires **macOS 14+** on **Apple Silicon**.

## Prerequisites

1. **Xcode Command Line Tools**

   ```sh
   xcode-select --install
   ```

2. **Ollama** (optional, for LLM cleanup of filler words and punctuation)

   Install from [ollama.com](https://ollama.com), then pull the default model:

   ```sh
   ollama pull gemma3:4b
   ```

   The app works fine without this — you'll just get raw Whisper transcripts.

## Build & run

```sh
git clone <this-repo>
cd LocalFlow
make app     # builds LocalFlow.app in the repo root (~2 min first time)
open LocalFlow.app
```

## First launch

1. **Whisper model download** — the Settings window opens automatically and downloads `ggml-small.en` (466 MB) into `~/Library/Application Support/LocalFlow/models/`. This is the only network request the app ever makes (besides Ollama on localhost).

2. **Accessibility permission** — macOS will ask "LocalFlow would like to control this computer." Grant it in **System Settings → Privacy & Security → Accessibility**. The menu-bar icon shows ⚠️ until this is done. No relaunch needed.

3. **Microphone permission** — prompted automatically on your first dictation.

## How to use

Hold **Right Option ⌥**, speak, release. Text appears at your cursor.

The menu-bar icon shows the current state: idle → 🎤 recording → 〰 transcribing → ✨ cleaning.

**Settings** (click the menu-bar icon → Settings…):

| Setting | Default | Options |
| --- | --- | --- |
| Activation key | Right ⌥ | Right/Left ⌥, Right ⌘, Right ⌃, F13–F15 |
| Mode | Hold-to-talk | Hold-to-talk, press-to-toggle |
| Whisper model | `small.en` | `base.en` (fastest), `small.en`, `large-v3-turbo` (most accurate) |
| LLM cleanup | On | On/off, configurable model |
| Injection method | Paste | Paste (default), keystrokes |

## Known limitations

- **Password fields** — secure input blocks text injection at the OS level. Dictation into password boxes won't work.
- **English only** — the Whisper models and cleanup prompt are English-specific.
- **Clipboard** — in paste mode your clipboard is briefly replaced (≈0.6 s) then restored.
