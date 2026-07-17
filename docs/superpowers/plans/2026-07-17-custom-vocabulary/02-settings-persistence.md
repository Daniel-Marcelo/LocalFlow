# Task 2: Settings Persistence

Self-contained. You need only this file and the repository. **Depends on Task 1**
(`VocabularyEntry` must already exist and be `Codable`).

## Context

`Settings` (`Sources/LocalFlowCore/Support/Settings.swift`) is an
`ObservableObject` whose properties are computed over `UserDefaults`. Unknown or
garbage stored values silently fall back to defaults. Every write bumps
`changeCounter` so SwiftUI refreshes.

This task adds a `vocabulary: [VocabularyEntry]` property, JSON-encoded into a
single `UserDefaults` key. It stores entries **raw** (as edited) — normalization
happens only inside the `Vocabulary` value at derivation time. Undecodable data
falls back to an empty list, matching the file's "garbage → default" rule.

The `defaults` stored property is already accessible inside the type:

```swift
public final class Settings: ObservableObject {
    private let defaults: UserDefaults
    @Published public private(set) var changeCounter = 0
    // ...
}
```

**Global constraints:** Swift 6.1, language mode v5. Tests use **Swift Testing**,
run via `./scripts/test.sh --filter SettingsTests`. Vocabulary is **not** a
pipeline-restarting setting (the editor writes it directly, not through the
`SettingsView` `binding(_:restartsPipeline:)` helper).

## Files

- Modify: `Sources/LocalFlowCore/Support/Settings.swift`
- Test: `Tests/LocalFlowTests/SettingsTests.swift`

## Interfaces

- Consumes: `VocabularyEntry` (Task 1).
- Produces:
  ```swift
  public var vocabulary: [VocabularyEntry] { get set }   // on Settings
  ```

## Steps

- [ ] **Step 1: Write the failing tests**

Add these three tests inside the existing `@Suite struct SettingsTests` in
`Tests/LocalFlowTests/SettingsTests.swift` (the `freshDefaults(_:)` helper is
already defined at the top of that file):

```swift
    @Test func vocabularyDefaultsToEmpty() {
        let settings = Settings(defaults: freshDefaults("vocab-empty"))
        #expect(settings.vocabulary.isEmpty)
    }

    @Test func vocabularyPersistsAcrossInstances() {
        let defaults = freshDefaults("vocab-persist")
        let settings = Settings(defaults: defaults)
        settings.vocabulary = [
            VocabularyEntry(term: "Claude Code", variants: ["clod code"]),
            VocabularyEntry(term: "Kubernetes", variants: []),
        ]
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.vocabulary == settings.vocabulary)
        #expect(reloaded.vocabulary.map(\.term) == ["Claude Code", "Kubernetes"])
    }

    @Test func garbageVocabularyFallsBackToEmpty() {
        let defaults = freshDefaults("vocab-garbage")
        defaults.set("not json", forKey: "vocabulary")
        let settings = Settings(defaults: defaults)
        #expect(settings.vocabulary.isEmpty)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./scripts/test.sh --filter SettingsTests`
Expected: FAILS to build — `value of type 'Settings' has no member 'vocabulary'`.

- [ ] **Step 3: Write the implementation**

In `Sources/LocalFlowCore/Support/Settings.swift`, add this computed property
inside the `Settings` class (e.g. just after the `soundCuesEnabled` property):

```swift
    /// Custom vocabulary, stored raw (un-normalized) as JSON. Undecodable data
    /// falls back to an empty list. Consumed via `Vocabulary(entries:)`.
    public var vocabulary: [VocabularyEntry] {
        get {
            guard
                let data = defaults.data(forKey: "vocabulary"),
                let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data)
            else { return [] }
            return entries
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: "vocabulary")
            changeCounter += 1
        }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./scripts/test.sh --filter SettingsTests`
Expected: PASS — the existing `SettingsTests` plus the three new ones are green.

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalFlowCore/Support/Settings.swift Tests/LocalFlowTests/SettingsTests.swift
git commit -m "feat: persist custom vocabulary in Settings"
```
