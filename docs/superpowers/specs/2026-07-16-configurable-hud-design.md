# Configurable HUD — Design

**Date:** 2026-07-16
**Status:** Approved

## Summary

LocalFlow shows a floating **HUD** — a capsule near the bottom-center of the
screen — while dictating (activated by the global hotkey, default Right ⌥). It
renders a live waveform and a state label ("Listening", "Transcribing…",
"Cleaning…"). Today the only control is a single toggle, "Show HUD while
dictating".

This feature makes the HUD's **size**, **appearance**, and **behavior**
configurable through a small set of presets, with a **live preview** in the
Settings window. Position stays fixed (bottom-center) — explicitly out of
scope.

## Goals

- Three preset dimensions the user can pick independently:
  - **Size:** `Compact` / `Standard` / `Large`
  - **Style:** `System` / `Minimal` / `Vibrant`
  - **Behavior:** `Full pipeline` / `Recording only`
- A live preview in Settings that renders the *actual* HUD view with the
  selected presets, so appearance changes are seen immediately.
- Zero behavior change for existing users: defaults reproduce today's HUD
  exactly.

## Non-Goals (YAGNI)

- Configurable position (kept bottom-center).
- Fine-grained individual controls (color pickers, opacity sliders, size
  sliders). Presets only.
- Per-app or per-hotkey HUD variations.

## Preset Semantics

### Size — `HUDSize`

Resolves to a concrete panel `CGSize` and a `scale` multiplier applied to
fonts, waveform bar heights, spacing, and padding.

| Case       | panelSize (w×h) | scale |
| ---------- | --------------- | ----- |
| `compact`  | 180 × 44        | 0.82  |
| `standard` | 230 × 52        | 1.0   |
| `large`    | 300 × 66        | 1.3   |

`standard` reproduces today's fixed `HUDView.size` of 230×52 at scale 1.0.

### Style — `HUDStyle`

Resolves to a `HUDStyleSpec` describing tints per pipeline stage, whether the
text label shows, and the capsule opacity. (The "monochrome" look of `minimal`
falls out of using `.primary` tints — no separate flag.)

| Case      | recording tint | transcribing tint | cleaning tint | showLabel | opacity |
| --------- | -------------- | ----------------- | ------------- | --------- | ------- |
| `system`  | red            | cyan              | purple        | true      | 1.0     |
| `minimal` | primary        | primary           | primary       | false     | 0.9     |
| `vibrant` | pink           | blue              | purple        | true      | 1.0     |

`system` reproduces today's look (red live waveform, cyan traveling wave,
purple sparkle, label shown, ultra-thin material at full opacity).

### Behavior — `HUDBehavior`

A pure function `shouldShow(state:) -> Bool` decides HUD visibility per
pipeline state. Errors always surface briefly (the caller adds a short
auto-hide) regardless of behavior.

| state          | `fullPipeline` | `recordingOnly` |
| -------------- | -------------- | --------------- |
| `idle`         | false          | false           |
| `recording`    | true           | true            |
| `transcribing` | true           | false           |
| `cleaning`     | true           | false           |
| `error`        | true           | true            |

`fullPipeline` reproduces today's behavior (HUD stays visible through
transcribing and cleaning).

## Architecture

- **`HUDAppearance.swift` (new):** the three enums, their resolvers
  (`panelSize`, `scale`, `spec`, `shouldShow`), the `HUDStyleSpec` value type,
  and a small `HUDAppearance` struct pairing a size + style for passing into
  the HUD. Pure, testable, depends only on SwiftUI + the existing
  `DictationState`.
- **`Settings.swift` (edit):** three new UserDefaults-backed properties
  (`hudSize`, `hudStyle`, `hudBehavior`), following the existing computed
  property pattern. Cosmetic — never restart the pipeline.
- **`HUDController.swift` (edit):** `show(state:)` gains an `appearance:`
  argument. The panel is resized on each `show` (size can change between
  dictations). `HUDModel` carries the current `appearance`; `HUDView` reads it
  to drive frame, tints, label visibility, and scale.
- **`AppDelegate.swift` (edit):** `updateHUD(for:)` builds the appearance from
  settings and consults `HUDBehavior.shouldShow(state:)` to decide show vs.
  hide. The `hudEnabled` master toggle still short-circuits everything.
- **`SettingsView.swift` (edit):** a new **"HUD"** section holding the existing
  "Show HUD while dictating" toggle, three preset pickers, and a `HUDPreview`
  subview rendering the real `HUDView` in a `.recording` state with sample
  levels.

`HUDController` stays free of a `Settings` dependency — `AppDelegate` resolves
the appearance and passes it in.

## Testing Strategy

- **Pure logic (unit tested, TDD):** size/style resolvers and the
  `shouldShow(state:)` truth table in `HUDAppearanceTests`; new settings
  defaults and round-trip in `SettingsTests`.
- **AppKit/SwiftUI wiring (compile + manual):** `HUDController`,
  `AppDelegate`, and `SettingsView` changes are verified with `swift build`
  and a manual check of the running app, since they render UI rather than
  compute values.

## Files Touched

- Create: `Sources/LocalFlowCore/UI/HUDAppearance.swift`
- Create: `Tests/LocalFlowTests/HUDAppearanceTests.swift`
- Modify: `Sources/LocalFlowCore/Support/Settings.swift`
- Modify: `Sources/LocalFlowCore/UI/HUDController.swift`
- Modify: `Sources/LocalFlowCore/Core/AppDelegate.swift`
- Modify: `Sources/LocalFlowCore/UI/SettingsView.swift`
- Modify: `Tests/LocalFlowTests/SettingsTests.swift`
