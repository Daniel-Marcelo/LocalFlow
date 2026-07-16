# Task 1: HUD Appearance Model

Self-contained. You need only this file and the repository.

## Context

LocalFlow's dictation HUD will become configurable along three preset
dimensions: **size**, **style**, and **behavior**. This task creates the pure,
testable model for those presets. It has no UI and no `Settings` wiring yet —
later tasks consume the types you define here.

`DictationState` already exists (public enum in
`Sources/LocalFlowCore/Core/DictationController.swift`):

```swift
public enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case cleaning
    case error(String)
    // ...
}
```

Follow the existing enum pattern used by `ActivationMode` / `InjectionMethod`
in `Sources/LocalFlowCore/Support/Settings.swift`: `String` raw value,
`CaseIterable`, `Identifiable` with `var id: String { rawValue }`, and a
`displayName`.

**Global constraints:** Swift 6.1, language mode v5, macOS 14+. Everything in
the `LocalFlowCore` module. Tests use **Swift Testing** (`import Testing`),
not XCTest.

## Files

- Create: `Sources/LocalFlowCore/UI/HUDAppearance.swift`
- Test: `Tests/LocalFlowTests/HUDAppearanceTests.swift`

## Interfaces

**Produces** (later tasks rely on these exact names/types):

- `public enum HUDSize: String, CaseIterable, Identifiable` with
  `var displayName: String`, `var panelSize: CGSize`, `var scale: CGFloat`.
  Cases: `compact`, `standard`, `large`.
- `public enum HUDStyle: String, CaseIterable, Identifiable` with
  `var displayName: String`, `var spec: HUDStyleSpec`. Cases: `system`,
  `minimal`, `vibrant`.
- `public struct HUDStyleSpec` with public fields `recordingTint: Color`,
  `transcribingTint: Color`, `cleaningTint: Color`, `showLabel: Bool`,
  `backgroundOpacity: Double`.
- `public enum HUDBehavior: String, CaseIterable, Identifiable` with
  `var displayName: String` and `func shouldShow(state: DictationState) -> Bool`.
  Cases: `fullPipeline`, `recordingOnly`.
- `public struct HUDAppearance` pairing `size: HUDSize` + `style: HUDStyle`
  with a public memberwise-style init.

**Consumes:** `DictationState` (already defined).

## Steps

- [ ] **Step 1: Write the failing tests**

Create `Tests/LocalFlowTests/HUDAppearanceTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import LocalFlowCore

@Suite struct HUDAppearanceTests {

    // MARK: Size

    @Test func everySizeRoundTripsAndHasADisplayName() {
        for size in HUDSize.allCases {
            #expect(HUDSize(rawValue: size.rawValue) == size)
            #expect(!size.displayName.isEmpty)
            #expect(size.id == size.rawValue)
        }
    }

    @Test func standardSizeReproducesLegacyHUD() {
        #expect(HUDSize.standard.panelSize == CGSize(width: 230, height: 52))
        #expect(HUDSize.standard.scale == 1.0)
    }

    @Test func compactIsSmallerAndLargeIsBigger() {
        #expect(HUDSize.compact.panelSize.width < HUDSize.standard.panelSize.width)
        #expect(HUDSize.large.panelSize.width > HUDSize.standard.panelSize.width)
        #expect(HUDSize.compact.scale < 1.0)
        #expect(HUDSize.large.scale > 1.0)
    }

    // MARK: Style

    @Test func everyStyleRoundTripsAndHasADisplayName() {
        for style in HUDStyle.allCases {
            #expect(HUDStyle(rawValue: style.rawValue) == style)
            #expect(!style.displayName.isEmpty)
        }
    }

    @Test func systemStyleShowsAColorLabel() {
        let spec = HUDStyle.system.spec
        #expect(spec.showLabel)
        #expect(spec.backgroundOpacity == 1.0)
    }

    @Test func minimalStyleHidesLabelAndDimsBackground() {
        let spec = HUDStyle.minimal.spec
        #expect(!spec.showLabel)
        #expect(spec.backgroundOpacity < 1.0)
    }

    // MARK: Behavior

    @Test func fullPipelineShowsForEveryActiveState() {
        let b = HUDBehavior.fullPipeline
        #expect(!b.shouldShow(state: .idle))
        #expect(b.shouldShow(state: .recording))
        #expect(b.shouldShow(state: .transcribing))
        #expect(b.shouldShow(state: .cleaning))
        #expect(b.shouldShow(state: .error("boom")))
    }

    @Test func recordingOnlyHidesDuringPostProcessing() {
        let b = HUDBehavior.recordingOnly
        #expect(!b.shouldShow(state: .idle))
        #expect(b.shouldShow(state: .recording))
        #expect(!b.shouldShow(state: .transcribing))
        #expect(!b.shouldShow(state: .cleaning))
        #expect(b.shouldShow(state: .error("boom")))
    }

    @Test func behaviorAndSizeAndStyleAllHaveDisplayNames() {
        for b in HUDBehavior.allCases { #expect(!b.displayName.isEmpty) }
    }

    // MARK: Appearance

    @Test func appearancePairsSizeAndStyle() {
        let a = HUDAppearance(size: .large, style: .vibrant)
        #expect(a.size == .large)
        #expect(a.style == .vibrant)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./scripts/test.sh --filter HUDAppearanceTests`
Expected: FAIL — `cannot find 'HUDSize' in scope` (and the other new types).

- [ ] **Step 3: Create the implementation**

Create `Sources/LocalFlowCore/UI/HUDAppearance.swift`:

```swift
import SwiftUI

/// The visual size of the dictation HUD. Resolves to a concrete panel size and
/// a `scale` multiplier applied to fonts, waveform bars, spacing and padding.
public enum HUDSize: String, CaseIterable, Identifiable {
    case compact, standard, large

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .standard: return "Standard"
        case .large: return "Large"
        }
    }

    /// The HUD panel's content size in points. `standard` matches the legacy
    /// fixed HUD size.
    public var panelSize: CGSize {
        switch self {
        case .compact: return CGSize(width: 180, height: 44)
        case .standard: return CGSize(width: 230, height: 52)
        case .large: return CGSize(width: 300, height: 66)
        }
    }

    /// Multiplier for fonts, bar heights, spacing and padding relative to
    /// `standard`.
    public var scale: CGFloat {
        switch self {
        case .compact: return 0.82
        case .standard: return 1.0
        case .large: return 1.3
        }
    }
}

/// A named visual theme for the HUD. Resolves to a `HUDStyleSpec` the view
/// reads for tints, label visibility and opacity.
public enum HUDStyle: String, CaseIterable, Identifiable {
    case system, minimal, vibrant

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .minimal: return "Minimal"
        case .vibrant: return "Vibrant"
        }
    }

    public var spec: HUDStyleSpec {
        switch self {
        case .system:
            return HUDStyleSpec(
                recordingTint: .red, transcribingTint: .cyan, cleaningTint: .purple,
                showLabel: true, backgroundOpacity: 1.0
            )
        case .minimal:
            return HUDStyleSpec(
                recordingTint: .primary, transcribingTint: .primary, cleaningTint: .primary,
                showLabel: false, backgroundOpacity: 0.9
            )
        case .vibrant:
            return HUDStyleSpec(
                recordingTint: .pink, transcribingTint: .blue, cleaningTint: .purple,
                showLabel: true, backgroundOpacity: 1.0
            )
        }
    }
}

/// Concrete visual attributes resolved from a `HUDStyle`.
public struct HUDStyleSpec {
    public let recordingTint: Color
    public let transcribingTint: Color
    public let cleaningTint: Color
    public let showLabel: Bool
    public let backgroundOpacity: Double

    public init(
        recordingTint: Color, transcribingTint: Color, cleaningTint: Color,
        showLabel: Bool, backgroundOpacity: Double
    ) {
        self.recordingTint = recordingTint
        self.transcribingTint = transcribingTint
        self.cleaningTint = cleaningTint
        self.showLabel = showLabel
        self.backgroundOpacity = backgroundOpacity
    }
}

/// How long the HUD stays visible across the pipeline. Errors always surface
/// (the caller adds a short auto-hide) regardless of behavior.
public enum HUDBehavior: String, CaseIterable, Identifiable {
    case fullPipeline, recordingOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fullPipeline: return "Full pipeline"
        case .recordingOnly: return "Recording only"
        }
    }

    /// Whether the HUD should be visible for a given pipeline state.
    public func shouldShow(state: DictationState) -> Bool {
        switch state {
        case .idle:
            return false
        case .recording, .error:
            return true
        case .transcribing, .cleaning:
            return self == .fullPipeline
        }
    }
}

/// A resolved size + style, passed into the HUD when it is shown.
public struct HUDAppearance {
    public let size: HUDSize
    public let style: HUDStyle

    public init(size: HUDSize, style: HUDStyle) {
        self.size = size
        self.style = style
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./scripts/test.sh --filter HUDAppearanceTests`
Expected: PASS (all tests in the suite green).

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalFlowCore/UI/HUDAppearance.swift Tests/LocalFlowTests/HUDAppearanceTests.swift
git commit -m "feat(hud): add configurable size/style/behavior preset model"
```
