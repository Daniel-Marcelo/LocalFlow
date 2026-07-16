# Task 4: Settings UI + Live Preview

Self-contained. You need only this file and the repository. **Depends on Tasks
1–3** (`HUDSize`/`HUDStyle`/`HUDBehavior`, `Settings.hudSize/hudStyle/hudBehavior`,
and the size/style-aware `HUDView`/`HUDModel`/`HUDAppearance`).

## Context

`SettingsView` (`Sources/LocalFlowCore/UI/SettingsView.swift`) is a SwiftUI
`Form`. `Settings` exposes computed UserDefaults-backed properties, so bindings
are built manually via the file's private `binding(_:restartsPipeline:)` helper
— cosmetic settings pass `restartsPipeline: false`.

Today the HUD has a single control living in the **Output** section:

```swift
Section("Output") {
    Picker("Injection method", selection: binding(\.injectionMethod, restartsPipeline: false)) {
        ForEach(InjectionMethod.allCases) { method in
            Text(method.displayName).tag(method)
        }
    }
    Toggle("Show HUD while dictating", isOn: binding(\.hudEnabled, restartsPipeline: false))
    Toggle("Play start/stop sounds", isOn: binding(\.soundCuesEnabled, restartsPipeline: false))
}
```

This task moves the HUD toggle into a dedicated **HUD** section, adds the three
preset pickers, and adds a **live preview** that renders the real `HUDView` in a
`.recording` state with a fixed sample waveform — so appearance changes are seen
immediately without triggering a real dictation.

This is SwiftUI UI — there is **no unit test**. Verify with `swift build` plus
the manual check.

**Global constraints:** Swift 6.1, language mode v5, `LocalFlowCore` module. New
bindings must use `restartsPipeline: false`. `HUDModel`/`HUDView`/`HUDAppearance`
are module-internal — `SettingsView` is in the same module, so it can use them
directly.

## Files

- Modify: `Sources/LocalFlowCore/UI/SettingsView.swift`

## Interfaces

**Consumes:** `HUDSize`, `HUDStyle`, `HUDBehavior`, `HUDAppearance` (Task 1);
`Settings.hudSize/hudStyle/hudBehavior` (Task 2); `HUDView`, `HUDModel`,
`HUDModel.barCount`, `HUDModel.appearance` (Task 3). **Produces:** nothing later
tasks consume (terminal task).

## Steps

- [ ] **Step 1: Remove the HUD toggle from the Output section**

In `Sources/LocalFlowCore/UI/SettingsView.swift`, change the `Output` section so
it no longer contains the "Show HUD while dictating" toggle. The `Output`
section should become:

```swift
Section("Output") {
    Picker("Injection method", selection: binding(\.injectionMethod, restartsPipeline: false)) {
        ForEach(InjectionMethod.allCases) { method in
            Text(method.displayName).tag(method)
        }
    }
    Toggle("Play start/stop sounds", isOn: binding(\.soundCuesEnabled, restartsPipeline: false))
}
```

- [ ] **Step 2: Add the HUD section**

Immediately **after** the `Output` section (and before the `Permissions`
section), insert:

```swift
Section("HUD") {
    Toggle("Show HUD while dictating", isOn: binding(\.hudEnabled, restartsPipeline: false))
    Picker("Size", selection: binding(\.hudSize, restartsPipeline: false)) {
        ForEach(HUDSize.allCases) { size in
            Text(size.displayName).tag(size)
        }
    }
    .disabled(!settings.hudEnabled)
    Picker("Style", selection: binding(\.hudStyle, restartsPipeline: false)) {
        ForEach(HUDStyle.allCases) { style in
            Text(style.displayName).tag(style)
        }
    }
    .disabled(!settings.hudEnabled)
    Picker("Visibility", selection: binding(\.hudBehavior, restartsPipeline: false)) {
        ForEach(HUDBehavior.allCases) { behavior in
            Text(behavior.displayName).tag(behavior)
        }
    }
    .disabled(!settings.hudEnabled)
    HUDPreview(size: settings.hudSize, style: settings.hudStyle)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
        .opacity(settings.hudEnabled ? 1 : 0.35)
}
```

- [ ] **Step 3: Add the `HUDPreview` view**

At **file scope** (after the closing brace of `struct SettingsView`), add:

```swift
/// A live, non-interactive preview of the HUD in its listening state, rendered
/// with the real `HUDView` so it exactly matches what appears while dictating.
/// The `.id` forces a rebuild (and a fresh model) whenever the presets change.
private struct HUDPreview: View {
    let size: HUDSize
    let style: HUDStyle

    var body: some View {
        HUDView(model: previewModel)
            .id("\(size.rawValue)-\(style.rawValue)")
    }

    private var previewModel: HUDModel {
        let model = HUDModel()
        model.state = .recording
        model.appearance = HUDAppearance(size: size, style: style)
        model.levels = HUDPreview.sampleLevels
        return model
    }

    /// A fixed, symmetric hump so the preview waveform is stable and readable.
    /// Sized to `HUDModel.barCount` so it always fills the waveform.
    private static let sampleLevels: [Float] = (0..<HUDModel.barCount).map { index in
        let t = Float(index) / Float(HUDModel.barCount - 1)  // 0...1
        return 0.25 + 0.6 * (1 - abs(2 * t - 1))             // low → high → low
    }
}
```

- [ ] **Step 4: Compile**

Run: `swift build`
Expected: build succeeds. (If it errors that the `whisper` product is missing,
run `./scripts/fetch-whisper.sh` once, then retry.)

- [ ] **Step 5: Manual check**

Run: `make run`, then open the menu-bar icon → **Settings…** → **HUD** section.
Expected:
- A preview capsule with a red waveform and "Listening" label is visible.
- Changing **Size** (Compact/Standard/Large) resizes the preview immediately.
- Changing **Style** to **Minimal** drops the label and goes monochrome; **Vibrant**
  changes the tint. The preview updates instantly.
- Turning **Show HUD while dictating** off disables the pickers and dims the
  preview.
- Set **Visibility** to **Recording only**, dictate: the HUD disappears the
  moment you stop talking (no transcribing/cleaning HUD).

- [ ] **Step 6: Run the full suite (regression) and commit**

Run: `make test`
Expected: PASS (all suites, including `HUDAppearanceTests` and `SettingsTests`).

```bash
git add Sources/LocalFlowCore/UI/SettingsView.swift
git commit -m "feat(hud): add HUD settings section with preset pickers and live preview"
```
