import SwiftUI

/// The SwiftUI settings form. `Settings` uses computed UserDefaults-backed
/// properties, so bindings are built manually against it.
struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var modelManager: ModelManager
    let controller: DictationController

    @State private var accessibilityGranted = Permissions.accessibilityGranted
    @State private var micStatusText = ""
    @State private var ollamaStatus: String?

    private let permissionTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Activation") {
                Picker("Activation key", selection: binding(\.hotkey)) {
                    ForEach(HotkeyChoice.allCases) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                Picker("Mode", selection: binding(\.activationMode)) {
                    ForEach(ActivationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Speech recognition") {
                Picker("Whisper model", selection: binding(\.whisperModel)) {
                    ForEach(WhisperModel.allCases) { model in
                        Text("\(model.displayName) · \(model.approximateSize)").tag(model)
                    }
                }
                modelStatusRow
            }

            Section("LLM cleanup (Ollama)") {
                Toggle("Clean up transcripts with a local LLM", isOn: binding(\.cleanupEnabled))
                TextField("Ollama model", text: binding(\.ollamaModel))
                    .disabled(!settings.cleanupEnabled)
                HStack {
                    Button("Test Ollama connection") { testOllama() }
                        .disabled(!settings.cleanupEnabled)
                    if let ollamaStatus {
                        Text(ollamaStatus).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Text("Transcripts up to \(CleanupGate.minimumLength) characters skip cleanup for lower latency. If Ollama is unreachable, the raw transcript is injected instead.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Output") {
                Picker("Injection method", selection: binding(\.injectionMethod)) {
                    ForEach(InjectionMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                Toggle("Show HUD while dictating", isOn: binding(\.hudEnabled))
                Toggle("Play start/stop sounds", isOn: binding(\.soundCuesEnabled))
            }

            Section("Permissions") {
                permissionRow(
                    name: "Accessibility",
                    granted: accessibilityGranted,
                    detail: "Required for the global hotkey and text injection.",
                    action: Permissions.openAccessibilitySettings
                )
                permissionRow(
                    name: "Microphone",
                    granted: Permissions.microphoneStatus == .authorized,
                    detail: micDetail,
                    action: Permissions.openMicrophoneSettings
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(permissionTimer) { _ in
            let granted = Permissions.accessibilityGranted
            if granted != accessibilityGranted {
                accessibilityGranted = granted
                if granted { controller.start() }
            }
        }
    }

    @ViewBuilder
    private var modelStatusRow: some View {
        switch modelManager.state {
        case .downloading(let progress):
            ProgressView(value: progress) {
                Text("Downloading \(settings.whisperModel.fileName)… \(Int(progress * 100))%")
                    .font(.callout)
            }
        case .failed(let message):
            HStack {
                Text("Download failed: \(message)").font(.callout).foregroundStyle(.red)
                Button("Retry") { downloadModel() }
            }
        case .idle:
            if settings.whisperModel.isDownloaded {
                Label("Model downloaded", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Label("Model not downloaded", systemImage: "exclamationmark.triangle")
                        .font(.callout)
                    Button("Download now (\(settings.whisperModel.approximateSize))") {
                        downloadModel()
                    }
                }
            }
        }
    }

    private var micDetail: String {
        switch Permissions.microphoneStatus {
        case .authorized: return "Granted."
        case .notDetermined: return "You'll be asked on your first dictation."
        default: return "Denied — enable it in System Settings."
        }
    }

    private func permissionRow(
        name: String, granted: Bool, detail: String, action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(granted ? .green : .orange)
            }
            Spacer()
            if !granted {
                Button("Open System Settings") { action() }
            }
        }
    }

    private func downloadModel() {
        Task { try? await controller.ensureModelReady() }
    }

    private func testOllama() {
        ollamaStatus = "Checking…"
        let config = settings.ollamaConfig
        Task {
            let outcome = await OllamaCleaner.clean(
                transcript: "um so this is like a quick test of the cleanup pipeline you know",
                config: config
            )
            ollamaStatus = outcome.fellBack
                ? "❌ \(outcome.fallbackReason ?? "unreachable")"
                : "✅ \(config.model) responded"
        }
    }

    /// Builds a SwiftUI binding onto a Settings computed property; the
    /// changeCounter publish makes the view refresh, and controller.start()
    /// re-wires the hotkey when activation settings change.
    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                controller.start()
            }
        )
    }
}
