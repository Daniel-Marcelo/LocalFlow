import AppKit
import SwiftUI

/// Presents the SwiftUI settings form in a regular window. The app is an
/// LSUIElement agent, so it must activate itself for the window to come
/// forward.
@MainActor
public final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: Settings
    private let controller: DictationController

    public init(settings: Settings, controller: DictationController) {
        self.settings = settings
        self.controller = controller
    }

    public func show() {
        if window == nil {
            let view = SettingsView(
                settings: settings,
                modelManager: controller.modelManager,
                controller: controller
            )
            let hosting = NSHostingController(rootView: view)
            // Let the window (not the SwiftUI intrinsic size) drive sizing, so
            // the grouped form scrolls instead of forcing an ever-taller window.
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.title = "LocalFlow Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            // Open at a comfortable height that always fits the screen; lock the
            // width to the form's 480pt and allow vertical resize.
            let ceiling = (NSScreen.main?.visibleFrame.height ?? 800) - 80
            window.setContentSize(NSSize(width: 480, height: min(640, ceiling)))
            window.contentMinSize = NSSize(width: 480, height: 320)
            window.contentMaxSize = NSSize(width: 480, height: 10_000)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
