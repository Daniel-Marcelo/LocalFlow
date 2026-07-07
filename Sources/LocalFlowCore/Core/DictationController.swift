import AppKit
import os.log

/// The pipeline states, mirrored by the status-item glyph and the HUD.
public enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case cleaning
    case error(String)

    public var label: String {
        switch self {
        case .idle: return "Idle"
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .cleaning: return "Cleaning…"
        case .error(let message): return "Error: \(message)"
        }
    }
}

/// Orchestrates the whole loop: hotkey → mic → Whisper → (Ollama) → inject.
@MainActor
public final class DictationController: ObservableObject {
    private let log = Logger(subsystem: "com.localflow.app", category: "pipeline")

    @Published public private(set) var state: DictationState = .idle
    /// Non-blocking warning surfaced in the menu (e.g. Ollama fallback).
    @Published public private(set) var warning: String?

    public let settings: Settings
    public let modelManager = ModelManager()
    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let hotkeyManager = HotkeyManager()

    /// Serializes transcriptions; whisper contexts are not thread-safe.
    private let whisperQueue = DispatchQueue(label: "com.localflow.whisper", qos: .userInitiated)

    public var onStateChange: ((DictationState) -> Void)?

    public init(settings: Settings) {
        self.settings = settings
    }

    // MARK: Lifecycle

    /// Wires the hotkey and warms the pipeline. Safe to call again after a
    /// settings change or once Accessibility is granted.
    public func start() {
        hotkeyManager.stop()
        hotkeyManager.hotkey = settings.hotkey
        hotkeyManager.mode = settings.activationMode
        hotkeyManager.onActivate = { [weak self] in self?.beginRecording() }
        hotkeyManager.onDeactivate = { [weak self] in self?.finishRecording() }

        if Permissions.accessibilityGranted {
            if !hotkeyManager.start() {
                setState(.error("Could not install the keyboard event tap"))
            }
        }

        if settings.cleanupEnabled {
            OllamaCleaner.warmUp(config: settings.ollamaConfig)
        }
        preloadModelIfAvailable()
    }

    public var hotkeyActive: Bool { hotkeyManager.isRunning }

    /// Loads the selected Whisper model into memory ahead of the first
    /// dictation (model load costs ~0.5–2 s that shouldn't be paid mid-flow).
    public func preloadModelIfAvailable() {
        let model = settings.whisperModel
        guard model.isDownloaded else { return }
        whisperQueue.async { [transcriber] in
            try? transcriber.load(model: model)
        }
    }

    /// Downloads the selected model if missing, then loads it.
    public func ensureModelReady() async throws {
        let model = settings.whisperModel
        _ = try await modelManager.ensureAvailable(model)
        preloadModelIfAvailable()
    }

    // MARK: Recording

    private func beginRecording() {
        guard state == .idle || isErrorState else { return }

        guard Permissions.microphoneStatus == .authorized else {
            handleMicrophonePermission()
            return
        }
        guard settings.whisperModel.isDownloaded else {
            setState(.error("Whisper model not downloaded — open Settings"))
            Task { try? await ensureModelReady() }
            return
        }
        do {
            try recorder.start()
            setState(.recording)
            if settings.soundCuesEnabled { SoundPlayer.playStart() }
        } catch {
            setState(.error(error.localizedDescription))
        }
    }

    private func finishRecording() {
        guard state == .recording else { return }
        let samples = recorder.stop()
        if settings.soundCuesEnabled { SoundPlayer.playStop() }
        process(samples: samples)
    }

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    private func handleMicrophonePermission() {
        switch Permissions.microphoneStatus {
        case .notDetermined:
            Task {
                let granted = await Permissions.requestMicrophone()
                self.setState(granted ? .idle : .error("Microphone access denied"))
            }
        default:
            setState(.error("Microphone access denied — enable it in System Settings"))
            Permissions.openMicrophoneSettings()
        }
    }

    // MARK: Pipeline

    private func process(samples: [Float]) {
        setState(.transcribing)
        let model = settings.whisperModel
        let cleanupEnabled = settings.cleanupEnabled
        let ollamaConfig = settings.ollamaConfig
        let injectionMethod = settings.injectionMethod

        whisperQueue.async { [weak self, transcriber] in
            let transcript: String
            do {
                try transcriber.load(model: model)
                transcript = TranscriptSanitizer.sanitize(
                    try transcriber.transcribe(samples: samples)
                )
            } catch {
                Task { @MainActor [weak self] in
                    self?.setState(.error(error.localizedDescription))
                    self?.scheduleErrorReset()
                }
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.cleanAndInject(
                    transcript: transcript,
                    cleanupEnabled: cleanupEnabled,
                    ollamaConfig: ollamaConfig,
                    injectionMethod: injectionMethod
                )
            }
        }
    }

    private func cleanAndInject(
        transcript: String,
        cleanupEnabled: Bool,
        ollamaConfig: OllamaConfig,
        injectionMethod: InjectionMethod
    ) async {
        guard !transcript.isEmpty else {
            log.info("Empty transcript; nothing to inject")
            setState(.idle)
            return
        }

        var finalText = transcript
        if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanupEnabled) {
            setState(.cleaning)
            let outcome = await OllamaCleaner.clean(transcript: transcript, config: ollamaConfig)
            finalText = outcome.text
            warning = outcome.fellBack
                ? "LLM cleanup unavailable (\(outcome.fallbackReason ?? "unknown")) — injected raw transcript"
                : nil
        }

        TextInjector.inject(finalText, method: injectionMethod)
        setState(.idle)
    }

    private func setState(_ newState: DictationState) {
        state = newState
        onStateChange?(newState)
        if case .error(let message) = newState {
            log.error("\(message, privacy: .public)")
            if settings.soundCuesEnabled { SoundPlayer.playError() }
            scheduleErrorReset()
        }
    }

    /// Errors are transient UI states; drop back to idle so the next
    /// dictation attempt isn't blocked.
    private func scheduleErrorReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, case .error = self.state else { return }
            self.setState(.idle)
        }
    }
}
