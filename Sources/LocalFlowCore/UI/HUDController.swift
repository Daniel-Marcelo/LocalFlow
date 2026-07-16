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
