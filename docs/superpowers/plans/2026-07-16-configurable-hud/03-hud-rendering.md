# Task 3: HUD Rendering + AppDelegate Wiring

Self-contained. You need only this file and the repository. **Depends on Tasks 1
& 2** (`HUDAppearance`, `HUDSize`, `HUDStyle`, `HUDStyleSpec`, and
`Settings.hudSize/hudStyle/hudBehavior`).

## Context

The HUD is a borderless, non-activating `NSPanel` created once and reused, with
a SwiftUI `HUDView` inside. Today it is a **fixed** 230×52 with hard-coded tints
(red / cyan / purple) and an always-visible label, and `AppDelegate` decides
show/hide with a hard-coded `switch` on state.

This task makes the HUD honor a `HUDAppearance` (size + style) end-to-end and
routes visibility through `HUDBehavior.shouldShow(state:)`. The rendering change
(a new `show` signature) and its **only caller** (`AppDelegate`) are updated
together so the build stays green.

This is AppKit/SwiftUI UI — there is **no unit test**. Verify with `swift build`
plus the manual check in the final step.

`AppDelegate.updateHUD` today:

```swift
private func updateHUD(for state: DictationState) {
    guard settings.hudEnabled else {
        hud.hide()
        return
    }
    switch state {
    case .idle:
        hud.hide()
    case .recording, .transcribing, .cleaning:
        hud.show(state: state)
    case .error:
        hud.show(state: state)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if case .idle = self?.controller.state ?? .idle {
                self?.hud.hide()
            }
        }
    }
}
```

`AppDelegate` already holds `settings` and a `hud` (`HUDController`).

**Global constraints:** Swift 6.1, language mode v5, `LocalFlowCore` module,
`@MainActor`.

## Files

- Modify: `Sources/LocalFlowCore/UI/HUDController.swift` (replace entire file)
- Modify: `Sources/LocalFlowCore/Core/AppDelegate.swift` (replace `updateHUD`)

## Interfaces

**Produces:**
- `HUDController.show(state: DictationState, appearance: HUDAppearance)`
- `HUDModel.appearance: HUDAppearance` (`@Published`) — used by Task 4's preview.
- `HUDView` / `HUDModel` stay module-internal.

**Consumes:** `HUDAppearance`, `HUDSize`, `HUDStyle`, `HUDStyleSpec`,
`HUDBehavior` (Task 1); `Settings.hudSize/hudStyle/hudBehavior` (Task 2);
`DictationState` (existing).

## Steps

- [ ] **Step 1: Replace `HUDController.swift`**

Replace the **entire** contents of `Sources/LocalFlowCore/UI/HUDController.swift`
with:

```swift
import AppKit
import SwiftUI

/// A small non-activating floating panel near the bottom of the screen that
/// mirrors the pipeline state. While listening it renders a live waveform
/// driven by microphone levels; transcribing shows a traveling wave; cleaning
/// shows a shimmering sparkle. Size and style come from a `HUDAppearance`
/// passed in on each `show`. Never steals focus from the app being dictated
/// into.
@MainActor
public final class HUDController {
    private var panel: NSPanel?
    private let model = HUDModel()

    public init() {}

    public func show(state: DictationState, appearance: HUDAppearance) {
        model.appearance = appearance
        model.state = state
        if case .recording = state {
            model.resetLevels()
        }
        let panel = ensurePanel()
        panel.setContentSize(appearance.size.panelSize)
        position(panel)
        panel.orderFrontRegardless()
    }

    public func pushLevel(_ level: Float) {
        model.pushLevel(level)
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let initialSize = HUDSize.standard.panelSize
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + frame.height * 0.12
        ))
    }
}

/// Observable state behind the HUD: pipeline stage, a rolling window of recent
/// mic levels that the listening waveform scrolls through, and the resolved
/// appearance (size + style).
@MainActor
final class HUDModel: ObservableObject {
    static let barCount = 21

    @Published var state: DictationState = .idle
    @Published var levels: [Float] = Array(repeating: 0, count: HUDModel.barCount)
    @Published var appearance = HUDAppearance(size: .standard, style: .system)

    func pushLevel(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func resetLevels() {
        levels = Array(repeating: 0, count: Self.barCount)
    }
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    private var size: CGSize { model.appearance.size.panelSize }
    private var scale: CGFloat { model.appearance.size.scale }
    private var spec: HUDStyleSpec { model.appearance.style.spec }

    var body: some View {
        HStack(spacing: 10 * scale) {
            if spec.showLabel {
                visual
                    .frame(width: 110 * scale, height: 26 * scale)
                Text(label)
                    .font(.system(size: 12 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                visual
                    .frame(height: 26 * scale)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 10 * scale)
        .frame(width: size.width, height: size.height)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .opacity(spec.backgroundOpacity)
    }

    private var label: String {
        switch model.state {
        case .idle: return ""
        case .recording: return "Listening"
        case .transcribing: return "Transcribing…"
        case .cleaning: return "Cleaning…"
        case .error(let message): return message
        }
    }

    @ViewBuilder
    private var visual: some View {
        switch model.state {
        case .recording:
            LiveWaveform(levels: model.levels, tint: spec.recordingTint)
        case .transcribing:
            TravelingWave(tint: spec.transcribingTint)
        case .cleaning:
            Image(systemName: "sparkles")
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundStyle(spec.cleaningTint)
                .symbolEffect(.variableColor.iterative, options: .repeating)
                .frame(maxWidth: .infinity)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
        case .idle:
            Color.clear
        }
    }
}

/// Bars that scroll with the actual microphone level history.
struct LiveWaveform: View {
    let levels: [Float]
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width / CGFloat(levels.count) * 0.62
            let gap = geometry.size.width / CGFloat(levels.count) * 0.38
            HStack(alignment: .center, spacing: gap) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(tint.opacity(0.55 + 0.45 * Double(levels[index])))
                        .frame(
                            width: barWidth,
                            height: max(3, geometry.size.height * CGFloat(levels[index]))
                        )
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.09), value: levels)
        }
    }
}

/// An indeterminate sine wave that travels while whisper works.
struct TravelingWave: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * 5
            GeometryReader { geometry in
                let count = 17
                let barWidth = geometry.size.width / CGFloat(count) * 0.62
                let gap = geometry.size.width / CGFloat(count) * 0.38
                HStack(alignment: .center, spacing: gap) {
                    ForEach(0..<count, id: \.self) { index in
                        let wave = (sin(phase + Double(index) * 0.55) + 1) / 2
                        Capsule()
                            .fill(tint.opacity(0.4 + 0.6 * wave))
                            .frame(
                                width: barWidth,
                                height: max(3, geometry.size.height * (0.25 + 0.75 * wave))
                            )
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}
```

Notes:
- The old `static let size = CGSize(width: 230, height: 52)` on `HUDView` is
  intentionally removed; sizing now comes from `model.appearance.size`. Its only
  former user was this file.
- `LiveWaveform` / `TravelingWave` are unchanged — they fill their
  `GeometryReader`, so scaling the `visual` frame scales them for free.

- [ ] **Step 2: Rewrite `updateHUD` in `AppDelegate.swift`**

In `Sources/LocalFlowCore/Core/AppDelegate.swift`, replace the entire existing
`updateHUD(for:)` method with:

```swift
    private func updateHUD(for state: DictationState) {
        guard settings.hudEnabled, settings.hudBehavior.shouldShow(state: state) else {
            hud.hide()
            return
        }
        let appearance = HUDAppearance(size: settings.hudSize, style: settings.hudStyle)
        hud.show(state: state, appearance: appearance)
        if case .error = state {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if case .idle = self?.controller.state ?? .idle {
                    self?.hud.hide()
                }
            }
        }
    }
```

This preserves the master `hudEnabled` toggle and the error auto-hide, and now
routes ordinary visibility through `HUDBehavior.shouldShow`.

- [ ] **Step 3: Compile**

Run: `swift build`
Expected: build succeeds with no errors. (If it errors that the `whisper`
product is missing, run `./scripts/fetch-whisper.sh` once, then retry.)

- [ ] **Step 4: Manual smoke check**

Run: `make run`, then dictate with the hotkey (default Right ⌥).
Expected: the HUD appears bottom-center at Standard size with the red waveform
and "Listening" label (identical to before — defaults unchanged), and stays
through transcribing/cleaning.

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalFlowCore/UI/HUDController.swift Sources/LocalFlowCore/Core/AppDelegate.swift
git commit -m "feat(hud): drive HUD size/style/visibility from settings presets"
```
