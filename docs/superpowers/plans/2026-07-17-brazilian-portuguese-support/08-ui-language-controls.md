# Task 8: UI — Menu Toggle + Settings Picker

**Files:**
- Modify: `Sources/LocalFlowCore/UI/StatusItemController.swift`
- Modify: `Sources/LocalFlowCore/UI/SettingsView.swift`
- Modify: `CLAUDE.md` (documentation update)

**Interfaces:**
- Consumes:
  - `DictationLanguage` (Task 1)
  - `WhisperModel.models(for:)` (Task 2)
  - `Settings.language` (Task 3)
  - `DictationController.start()` (existing)
- Produces:
  - Menu-bar language section (checkmarked per-language items)
  - Settings "Language" picker in the Speech recognition section
  - Whisper model picker filtered by active language

---

- [ ] **Step 1: Add language section to the menu bar**

In `Sources/LocalFlowCore/UI/StatusItemController.swift`, inside `menuNeedsUpdate(_:)`,
add a language section **before** the separator + activation hint (before line 89).

Insert this block after the warning item and before `menu.addItem(.separator())` at line 89:

```swift
menu.addItem(.separator())
for lang in DictationLanguage.allCases {
    let item = NSMenuItem(
        title: lang.displayName,
        action: #selector(switchLanguage(_:)),
        keyEquivalent: ""
    )
    item.target = self
    item.representedObject = lang
    item.state = lang == controller.settings.language ? .on : .off
    menu.addItem(item)
}
```

- [ ] **Step 2: Add the switchLanguage action method**

Add a new `@objc` method to `StatusItemController` (after the `openMicrophone` method):

```swift
@objc private func switchLanguage(_ sender: NSMenuItem) {
    guard let lang = sender.representedObject as? DictationLanguage else { return }
    controller.settings.language = lang
    controller.start()
}
```

- [ ] **Step 3: Verify the build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 4: Add language picker to SettingsView**

In `Sources/LocalFlowCore/UI/SettingsView.swift`, inside the `Section("Speech recognition")`
block (lines 32–39), add a language picker **before** the Whisper model picker:

```swift
Section("Speech recognition") {
    Picker("Language", selection: binding(\.language)) {
        ForEach(DictationLanguage.allCases) { lang in
            Text(lang.displayName).tag(lang)
        }
    }
    Picker("Whisper model", selection: binding(\.whisperModel)) {
        ForEach(WhisperModel.models(for: settings.language)) { model in
            Text("\(model.displayName) · \(model.approximateSize)").tag(model)
        }
    }
    modelStatusRow
}
```

Note the key change: `WhisperModel.allCases` → `WhisperModel.models(for: settings.language)`.

- [ ] **Step 5: Verify the build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 6: Run all tests to check for regressions**

Run: `make test`
Expected: all tests PASS.

- [ ] **Step 7: Update CLAUDE.md documentation**

In `CLAUDE.md`, make these changes:

1. In the "Known constraints" section at the bottom, replace:
   > English-only: the `.en` Whisper models and the cleanup prompt are both English-specific.

   with:
   > Languages: English and Brazilian Portuguese. The active language is selected manually in
   > Settings or the menu bar. PT-BR uses Whisper's `pt` language code (no distinction from
   > European Portuguese at the STT stage); the Brazilian character is applied by the PT-BR
   > cleanup prompt.

2. In the `WhisperTranscriber` description within "The pipeline" section, replace:
   > (the `CleanupGate` treats ≤50 chars as the common case)

   This remains accurate — no change needed.

3. In the headless pipeline section, update the command example:
   ```
   .build/release/LocalFlow --transcribe speech.aiff [--language en|pt] [--model base.en] [--no-cleanup] [--ollama-model gemma3:4b]
   ```

4. Remove/replace the line in "Known constraints":
   > English-only: the `.en` Whisper models and the cleanup prompt are both English-specific.

- [ ] **Step 8: Commit**

```bash
git add Sources/LocalFlowCore/UI/StatusItemController.swift Sources/LocalFlowCore/UI/SettingsView.swift CLAUDE.md
git commit -m "feat: add language picker to Settings and menu bar"
```
