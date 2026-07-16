# Task 2: Settings Properties

Self-contained. You need only this file and the repository. **Depends on Task 1**
(`HUDSize`, `HUDStyle`, `HUDBehavior` must already exist).

## Context

`Settings` (`Sources/LocalFlowCore/Support/Settings.swift`) is an
`ObservableObject` whose properties are computed over `UserDefaults`. Unknown
or garbage stored values silently fall back to defaults. Every write goes
through a private helper that bumps `changeCounter` so SwiftUI refreshes.

This task adds three persisted properties for the HUD presets. Defaults must
reproduce today's HUD: `.standard`, `.system`, `.fullPipeline`.

Existing helpers already in the file you will reuse:

```swift
private func rawString(_ key: String) -> String? {
    defaults.string(forKey: key)
}

private func set(_ value: String, forKey key: String) {
    defaults.set(value, forKey: key)
    changeCounter += 1
}
```

Existing property to mirror (same file):

```swift
public var injectionMethod: InjectionMethod {
    get { rawString("injectionMethod").flatMap(InjectionMethod.init(rawValue:)) ?? .paste }
    set { set(newValue.rawValue, forKey: "injectionMethod") }
}
```

**Global constraints:** Swift 6.1, language mode v5. Tests use **Swift
Testing**. New settings are cosmetic (later tasks bind them with
`restartsPipeline: false`).

## Files

- Modify: `Sources/LocalFlowCore/Support/Settings.swift`
- Test: `Tests/LocalFlowTests/SettingsTests.swift` (extend two existing tests)

## Interfaces

**Produces:** `Settings.hudSize: HUDSize`, `Settings.hudStyle: HUDStyle`,
`Settings.hudBehavior: HUDBehavior` (get/set, UserDefaults-backed).

**Consumes:** `HUDSize`, `HUDStyle`, `HUDBehavior` from Task 1.

## Steps

- [ ] **Step 1: Extend the failing tests**

In `Tests/LocalFlowTests/SettingsTests.swift`, add assertions to the two
existing tests. The current tests look like this:

```swift
@Test func freshDefaultsMatchSpec() {
    let settings = Settings(defaults: freshDefaults("fresh"))
    #expect(settings.hotkey == .rightOption)
    #expect(settings.activationMode == .hold)
    #expect(settings.whisperModel == .smallEN)
    #expect(settings.cleanupEnabled)
    #expect(settings.ollamaModel == "gemma3:4b")
    #expect(settings.injectionMethod == .paste)
    #expect(settings.hudEnabled)
    #expect(settings.soundCuesEnabled)
}
```

Add these three lines at the end of `freshDefaultsMatchSpec` (before the
closing brace):

```swift
    #expect(settings.hudSize == .standard)
    #expect(settings.hudStyle == .system)
    #expect(settings.hudBehavior == .fullPipeline)
```

The current `valuesPersistAcrossInstances` sets values, reloads from the same
defaults, and asserts they persisted. Inside its **write** block (where it
already sets `settings.hudEnabled = false` etc.), add:

```swift
    settings.hudSize = .large
    settings.hudStyle = .vibrant
    settings.hudBehavior = .recordingOnly
```

and inside its **reload** block (where it asserts `reloaded.hudEnabled` etc.),
add:

```swift
    #expect(reloaded.hudSize == .large)
    #expect(reloaded.hudStyle == .vibrant)
    #expect(reloaded.hudBehavior == .recordingOnly)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./scripts/test.sh --filter SettingsTests`
Expected: FAIL — `value of type 'Settings' has no member 'hudSize'`.

- [ ] **Step 3: Add the properties**

In `Sources/LocalFlowCore/Support/Settings.swift`, add these three computed
properties alongside the other public settings (e.g. right after the existing
`hudEnabled` property):

```swift
public var hudSize: HUDSize {
    get { rawString("hudSize").flatMap(HUDSize.init(rawValue:)) ?? .standard }
    set { set(newValue.rawValue, forKey: "hudSize") }
}

public var hudStyle: HUDStyle {
    get { rawString("hudStyle").flatMap(HUDStyle.init(rawValue:)) ?? .system }
    set { set(newValue.rawValue, forKey: "hudStyle") }
}

public var hudBehavior: HUDBehavior {
    get { rawString("hudBehavior").flatMap(HUDBehavior.init(rawValue:)) ?? .fullPipeline }
    set { set(newValue.rawValue, forKey: "hudBehavior") }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./scripts/test.sh --filter SettingsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalFlowCore/Support/Settings.swift Tests/LocalFlowTests/SettingsTests.swift
git commit -m "feat(hud): persist HUD size/style/behavior in Settings"
```
