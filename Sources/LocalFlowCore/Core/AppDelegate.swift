import AppKit
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: Settings!
    private var controller: DictationController!
    private var statusItemController: StatusItemController!
    private var settingsWindowController: SettingsWindowController!
    private let hud = HUDController()
    private var permissionPollTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt and braces with LSUIElement: never show a Dock icon, even when
        // launched as a bare executable during development.
        NSApp.setActivationPolicy(.accessory)

        WhisperTranscriber.silenceLogging()

        settings = Settings()
        controller = DictationController(settings: settings)
        settingsWindowController = SettingsWindowController(settings: settings, controller: controller)
        statusItemController = StatusItemController(controller: controller) { [weak self] in
            self?.settingsWindowController.show()
        }

        controller.onStateChange = { [weak self] state in
            self?.statusItemController.update(for: state)
            self?.updateHUD(for: state)
        }
        controller.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.statusItemController.update(for: self.controller.state)
            }
            .store(in: &cancellables)

        if !Permissions.accessibilityGranted {
            Permissions.requestAccessibility()
            startPollingForAccessibility()
        }

        controller.start()

        // First run: fetch the selected model right away so the first
        // dictation doesn't stall.
        if !settings.whisperModel.isDownloaded {
            Task { try? await controller.ensureModelReady() }
            settingsWindowController.show()
        }
    }

    /// AX trust changes don't post a notification; poll until granted, then
    /// bring the event tap up without requiring a relaunch.
    private func startPollingForAccessibility() {
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, Permissions.accessibilityGranted else { return }
            DispatchQueue.main.async {
                self.permissionPollTimer?.invalidate()
                self.permissionPollTimer = nil
                self.controller.start()
                self.statusItemController.update(for: self.controller.state)
            }
        }
    }

    private func updateHUD(for state: DictationState) {
        guard settings.hudEnabled else {
            hud.hide()
            return
        }
        switch state {
        case .idle:
            hud.hide()
        case .recording, .transcribing, .cleaning:
            hud.show(text: state.label)
        case .error(let message):
            hud.show(text: "⚠️ \(message)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if case .idle = self?.controller.state ?? .idle {
                    self?.hud.hide()
                }
            }
        }
    }
}
