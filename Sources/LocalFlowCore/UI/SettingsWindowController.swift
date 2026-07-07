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
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "LocalFlow Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
