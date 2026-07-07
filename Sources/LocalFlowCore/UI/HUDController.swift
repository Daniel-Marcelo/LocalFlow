import AppKit
import SwiftUI

/// A small non-activating floating panel near the bottom of the screen that
/// mirrors the pipeline state ("Listening… / Transcribing… / Cleaning…").
/// Never steals focus from the app being dictated into.
@MainActor
public final class HUDController {
    private var panel: NSPanel?

    public init() {}

    public func show(text: String) {
        let panel = ensurePanel()
        if let hosting = panel.contentView as? NSHostingView<HUDLabel> {
            hosting.rootView = HUDLabel(text: text)
        }
        position(panel)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 44),
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
        panel.contentView = NSHostingView(rootView: HUDLabel(text: ""))
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

struct HUDLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.72), in: Capsule())
            .frame(width: 180, height: 44)
    }
}
