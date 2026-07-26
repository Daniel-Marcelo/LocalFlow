import AppKit

/// Owns the NSStatusItem: a mic glyph that tracks pipeline state (and shows a
/// warning badge when permissions are missing or the LLM stage degraded),
/// plus the menu.
@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let controller: DictationController
    private let openSettings: () -> Void

    public init(controller: DictationController, openSettings: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.controller = controller
        self.openSettings = openSettings
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        update(for: controller.state)
    }

    public func update(for state: DictationState) {
        let (symbol, description): (String, String)
        if !Permissions.accessibilityGranted {
            (symbol, description) = ("exclamationmark.triangle", "LocalFlow — needs Accessibility permission")
        } else {
            switch state {
            case .idle:
                (symbol, description) = ("mic", "LocalFlow — idle")
            case .recording:
                (symbol, description) = ("mic.fill", "LocalFlow — listening")
            case .transcribing:
                (symbol, description) = ("waveform", "LocalFlow — transcribing")
            case .cleaning:
                (symbol, description) = ("sparkles", "LocalFlow — cleaning")
            case .error:
                (symbol, description) = ("mic.slash", "LocalFlow — error")
            }
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = description
    }

    // Rebuild the menu each time it opens so status lines are current.
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if !Permissions.accessibilityGranted {
            let fix = NSMenuItem(
                title: "⚠️ Grant Accessibility Permission…",
                action: #selector(openAccessibility), keyEquivalent: ""
            )
            fix.target = self
            menu.addItem(fix)
        }
        if Permissions.microphoneStatus == .denied {
            let fix = NSMenuItem(
                title: "⚠️ Grant Microphone Permission…",
                action: #selector(openMicrophone), keyEquivalent: ""
            )
            fix.target = self
            menu.addItem(fix)
        }
        if !controller.settings.whisperModel.isDownloaded {
            let title: String
            if case .downloading(let progress) = controller.modelManager.state {
                title = "Downloading model… \(Int(progress * 100))%"
            } else {
                title = "⚠️ Whisper model not downloaded — open Settings"
            }
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        if let warning = controller.warning {
            let item = NSMenuItem(title: "⚠️ \(warning)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())
        for lang in DictationLanguage.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: #selector(switchLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang
            item.state = lang == controller.settings.language ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let hint = NSMenuItem(title: activationHint, action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(showSettings), keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit LocalFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        menu.addItem(quit)
    }

    private var statusLine: String {
        "Status: \(controller.state.label)"
    }

    private var activationHint: String {
        let key = controller.settings.hotkey.displayName
        switch controller.settings.activationMode {
        case .hold: return "Hold \(key) to dictate"
        case .toggle: return "Press \(key) to start/stop dictation"
        }
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func openAccessibility() {
        Permissions.openAccessibilitySettings()
    }

    @objc private func openMicrophone() {
        Permissions.openMicrophoneSettings()
    }

    @objc private func switchLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? DictationLanguage else { return }
        controller.settings.language = lang
        controller.start()
    }
}
