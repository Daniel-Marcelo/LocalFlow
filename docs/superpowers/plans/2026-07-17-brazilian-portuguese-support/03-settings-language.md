# Task 3: Per-Language Settings Persistence

**Files:**
- Modify: `Sources/LocalFlowCore/Support/Settings.swift`
- Modify: `Tests/LocalFlowTests/SettingsTests.swift`

**Interfaces:**
- Consumes:
  - `DictationLanguage` (Task 1)
  - `WhisperModel.default(for:)`, `WhisperModel.supportedLanguages` (Task 2)
- Produces:
  - `Settings.language: DictationLanguage` (get/set, persisted, defaults to `.english`)
  - `Settings.whisperModel(for: DictationLanguage) -> WhisperModel`
  - `Settings.setWhisperModel(_:for:)` — persists to `whisperModel.<lang.rawValue>`
  - `Settings.whisperModel: WhisperModel` — convenience that reads/writes the active language's slot (preserves existing call-site API)
  - Migration: first read seeds `whisperModel.en` from legacy flat `whisperModel` key

---

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/LocalFlowTests/SettingsTests.swift` inside the existing `@Suite`:

```swift
@Test func languageDefaultsToEnglish() {
    let settings = Settings(defaults: freshDefaults("lang-default"))
    #expect(settings.language == .english)
}

@Test func languagePersistsAndRoundTrips() {
    let defaults = freshDefaults("lang-persist")
    let settings = Settings(defaults: defaults)
    settings.language = .portugueseBR
    let reloaded = Settings(defaults: defaults)
    #expect(reloaded.language == .portugueseBR)
}

@Test func languageGarbageFallsBackToDefault() {
    let defaults = freshDefaults("lang-garbage")
    defaults.set("xx", forKey: "language")
    let settings = Settings(defaults: defaults)
    #expect(settings.language == .english)
}

@Test func perLanguageModelIsolation() {
    let settings = Settings(defaults: freshDefaults("lang-model-iso"))
    settings.setWhisperModel(.largeV3Turbo, for: .english)
    settings.setWhisperModel(.small, for: .portugueseBR)
    #expect(settings.whisperModel(for: .english) == .largeV3Turbo)
    #expect(settings.whisperModel(for: .portugueseBR) == .small)
}

@Test func whisperModelConvenienceReadsActiveLanguage() {
    let settings = Settings(defaults: freshDefaults("lang-convenience"))
    settings.language = .portugueseBR
    settings.setWhisperModel(.baseQ5, for: .portugueseBR)
    #expect(settings.whisperModel == .baseQ5)
}

@Test func whisperModelConvenienceWritesActiveLanguage() {
    let settings = Settings(defaults: freshDefaults("lang-conv-write"))
    settings.language = .portugueseBR
    settings.whisperModel = .small
    #expect(settings.whisperModel(for: .portugueseBR) == .small)
    #expect(settings.whisperModel(for: .english) == .smallEN)
}

@Test func unsupportedPersistedModelFallsBackToLanguageDefault() {
    let defaults = freshDefaults("lang-model-unsupported")
    defaults.set("base.en", forKey: "whisperModel.pt")
    let settings = Settings(defaults: defaults)
    #expect(settings.whisperModel(for: .portugueseBR) == .small)
}

@Test func migrationSeedsENFromLegacyFlatKey() {
    let defaults = freshDefaults("lang-migration")
    defaults.set("large-v3-turbo", forKey: "whisperModel")
    let settings = Settings(defaults: defaults)
    #expect(settings.whisperModel(for: .english) == .largeV3Turbo)
}

@Test func migrationDoesNotOverwriteExistingENKey() {
    let defaults = freshDefaults("lang-migration-no-overwrite")
    defaults.set("large-v3-turbo", forKey: "whisperModel")
    defaults.set("base.en", forKey: "whisperModel.en")
    let settings = Settings(defaults: defaults)
    #expect(settings.whisperModel(for: .english) == .baseEN)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh --filter SettingsTests`
Expected: compilation failure — `Settings.language`, `whisperModel(for:)`, `setWhisperModel(_:for:)` don't exist.

- [ ] **Step 3: Write the implementation**

In `Sources/LocalFlowCore/Support/Settings.swift`, add the `language` property and the per-language model API. Replace the existing `whisperModel` computed property with the new version:

After the `activationMode` property (line 67), add:

```swift
public var language: DictationLanguage {
    get { rawString("language").flatMap(DictationLanguage.init(rawValue:)) ?? .default }
    set { set(newValue.rawValue, forKey: "language") }
}
```

Replace the existing `whisperModel` property (currently lines 69–72) with:

```swift
public func whisperModel(for language: DictationLanguage) -> WhisperModel {
    let key = "whisperModel.\(language.rawValue)"
    if let stored = rawString(key).flatMap(WhisperModel.init(rawValue:)),
       stored.supportedLanguages.contains(language) {
        return stored
    }
    if language == .english, rawString(key) == nil,
       let legacy = rawString("whisperModel").flatMap(WhisperModel.init(rawValue:)),
       legacy.supportedLanguages.contains(.english) {
        set(legacy.rawValue, forKey: key)
        return legacy
    }
    return .default(for: language)
}

public func setWhisperModel(_ model: WhisperModel, for language: DictationLanguage) {
    set(model.rawValue, forKey: "whisperModel.\(language.rawValue)")
}

public var whisperModel: WhisperModel {
    get { whisperModel(for: language) }
    set { setWhisperModel(newValue, for: language) }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh --filter SettingsTests`
Expected: all tests PASS (old and new).

- [ ] **Step 5: Verify the full build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 6: Update existing `freshDefaultsMatchSpec` test**

The existing test asserts `settings.whisperModel == .smallEN`. This still passes because `language` defaults to `.english` and the English default is `.smallEN`. No change needed — verify it still passes.

- [ ] **Step 7: Commit**

```bash
git add Sources/LocalFlowCore/Support/Settings.swift Tests/LocalFlowTests/SettingsTests.swift
git commit -m "feat: add per-language Whisper model settings with migration"
```
