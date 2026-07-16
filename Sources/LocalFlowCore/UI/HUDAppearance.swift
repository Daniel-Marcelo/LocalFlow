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
