# Configurable HUD — Implementation Plan (Overview)

> **For agentic workers:** Each task lives in its own file in this directory
> and is fully self-contained — an implementer needs only that one file plus
> the repository. Execute the tasks **in numeric order** (each consumes types
> the previous one produced). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make LocalFlow's dictation HUD configurable via size, style, and
behavior presets, with a live preview in Settings — without changing behavior
for existing users.

**Design spec:** `docs/superpowers/specs/2026-07-16-configurable-hud-design.md`
(background reference; each task file already embeds what it needs).

## Task Order & Dependencies

| # | File | Produces | Depends on |
| - | ---- | -------- | ---------- |
| 1 | `01-hud-appearance-model.md` | `HUDSize`, `HUDStyle`, `HUDStyleSpec`, `HUDBehavior`, `HUDAppearance` | — |
| 2 | `02-settings-properties.md` | `Settings.hudSize/hudStyle/hudBehavior` | 1 |
| 3 | `03-hud-rendering.md` | `HUDController.show(state:appearance:)`, size/style-aware `HUDView`/`HUDModel`, preset-driven show/hide in `AppDelegate` | 1, 2 |
| 4 | `04-settings-ui-and-preview.md` | HUD settings section + live preview | 1, 2, 3 |

Execute strictly in order — each task ends with a compiling, committable
deliverable. (Rendering and its only caller, `AppDelegate`, are done together in
Task 3 so the build never breaks mid-task.)

## Global Constraints

Every task's requirements implicitly include these:

- **Toolchain:** Swift 6.1, SwiftPM language mode **v5** (set per target in
  `Package.swift`). Target platform macOS 14+, Apple Silicon.
- **Module:** all source lives in the `LocalFlowCore` target under
  `Sources/LocalFlowCore/`. Tests live in `Tests/LocalFlowTests/` and use
  **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`) — not
  XCTest.
- **New enums follow the existing pattern** (see `ActivationMode` /
  `InjectionMethod` in `Support/Settings.swift`): `String` raw value,
  `CaseIterable`, `Identifiable` with `var id: String { rawValue }`, and a
  `displayName: String`.
- **New settings are UserDefaults-backed** via the existing private helpers on
  `Settings` (`rawString`, `set(_:forKey:)`) and are **cosmetic**: their
  SwiftUI bindings use `restartsPipeline: false` so they never tear down the
  event tap.
- **Defaults must reproduce today's HUD exactly:** `hudSize` default
  `.standard` (230×52, scale 1.0), `hudStyle` default `.system` (red
  waveform, label shown, ultra-thin material), `hudBehavior` default
  `.fullPipeline`.
- **TDD** for pure logic (tasks 1–2): failing test first, watch it fail, then
  implement. Tasks 3–5 are AppKit/SwiftUI UI — verify with `swift build` and a
  manual app check (no unit test).
- **One commit per task**, using the commit shown in that task's final step.

## Build & Test Commands

- Full test suite: `make test`
- Targeted suite: `./scripts/test.sh --filter <SuiteName>`
- Compile check: `swift build`
  - If `swift build` errors that the `whisper` product is missing, run
    `./scripts/fetch-whisper.sh` once first (vendors whisper.cpp), or use
    `make build`.

## Shared Context: today's HUD

- `DictationState` (public enum, in `Core/DictationController.swift`):
  `.idle`, `.recording`, `.transcribing`, `.cleaning`, `.error(String)`.
- The HUD is a borderless non-activating `NSPanel` created once and reused
  (`UI/HUDController.swift`). `AppDelegate` drives it from `onStateChange` /
  `onAudioLevel` callbacks.
- `Settings` (`Support/Settings.swift`) is an `ObservableObject` whose
  properties are computed over `UserDefaults`; every write bumps
  `changeCounter` so SwiftUI refreshes.

## Definition of Done

- `make test` passes (including the new `HUDAppearanceTests` and extended
  `SettingsTests`).
- `swift build` succeeds.
- Manual: launching the app, opening Settings → **HUD**, changing Size/Style
  updates the live preview; dictating shows the HUD at the chosen size/style;
  `Recording only` hides the HUD once speech stops; defaults look identical to
  the pre-change HUD.
