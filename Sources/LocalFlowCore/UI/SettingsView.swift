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
                TextField("Ollama model", text: binding(\.ollamaModel, restartsPipeline: false))
                    .disabled(!settings.cleanupEnabled)
                HStack {
                    Button("Test Ollama connection") { testOllama() }
                        .disabled(!settings.cleanupEnabled)
                    if let ollamaStatus {
                        Text(ollamaStatus).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Text("For lower latency, cleanup is skipped for transcripts up to \(CleanupGate.minimumLength) characters and for ones that already read clean (no filler words, proper punctuation). If Ollama is unreachable, the raw transcript is injected instead.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Output") {
                Picker("Injection method", selection: binding(\.injectionMethod, restartsPipeline: false)) {
                    ForEach(InjectionMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                Toggle("Play start/stop sounds", isOn: binding(\.soundCuesEnabled, restartsPipeline: false))
            }

            Section("HUD") {
                Toggle("Show HUD while dictating", isOn: binding(\.hudEnabled, restartsPipeline: false))
                Picker("Size", selection: binding(\.hudSize, restartsPipeline: false)) {
                    ForEach(HUDSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .disabled(!settings.hudEnabled)
                Picker("Style", selection: binding(\.hudStyle, restartsPipeline: false)) {
                    ForEach(HUDStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .disabled(!settings.hudEnabled)
                Picker("Visibility", selection: binding(\.hudBehavior, restartsPipeline: false)) {
                    ForEach(HUDBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .disabled(!settings.hudEnabled)
                HUDPreview(size: settings.hudSize, style: settings.hudStyle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                    .opacity(settings.hudEnabled ? 1 : 0.35)
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
        .frame(maxHeight: .infinity)
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
    /// changeCounter publish makes the view refresh. Pipeline-affecting
    /// settings restart the controller (re-wiring the hotkey, preloading the
    /// model, warming Ollama); cosmetic ones don't — notably the Ollama model
    /// text field, which would otherwise tear down the event tap on every
    /// keystroke.
    private func binding<Value>(
        _ keyPath: ReferenceWritableKeyPath<Settings, Value>,
        restartsPipeline: Bool = true
    ) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                if restartsPipeline {
                    controller.start()
                }
            }
        )
    }
}

/// A live, non-interactive preview of the HUD in its listening state, rendered
/// with the real `HUDView` so it exactly matches what appears while dictating.
/// The `.id` forces a rebuild (and a fresh model) whenever the presets change.
private struct HUDPreview: View {
    let size: HUDSize
    let style: HUDStyle

    var body: some View {
        HUDView(model: previewModel)
            .id("\(size.rawValue)-\(style.rawValue)")
    }

    private var previewModel: HUDModel {
        let model = HUDModel()
        model.state = .recording
        model.appearance = HUDAppearance(size: size, style: style)
        model.levels = HUDPreview.sampleLevels
        return model
    }

    /// A fixed, symmetric hump so the preview waveform is stable and readable.
    /// Sized to `HUDModel.barCount` so it always fills the waveform.
    private static let sampleLevels: [Float] = (0..<HUDModel.barCount).map { index in
        let t = Float(index) / Float(HUDModel.barCount - 1)  // 0...1
        return 0.25 + 0.6 * (1 - abs(2 * t - 1))             // low → high → low
    }
}
