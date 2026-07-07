import Foundation

/// Headless pipeline runner behind `LocalFlow --transcribe <audio-file>`.
/// Exercises audio loading → Whisper → sanitize → gate → Ollama cleanup
/// without needing the hotkey, microphone, or Accessibility permission.
/// Used to verify the STT and LLM stages from a terminal.
public enum PipelineCLI {
    public static func run(arguments: [String]) async -> Int32 {
        var audioPath: String?
        var model = WhisperModel.default
        var cleanup = true
        var ollamaModel = "gemma3:4b"

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--transcribe":
                audioPath = iterator.next()
            case "--model":
                if let raw = iterator.next(), let parsed = WhisperModel(rawValue: raw) {
                    model = parsed
                } else {
                    fputs("Unknown model; valid: \(WhisperModel.allCases.map(\.rawValue).joined(separator: ", "))\n", stderr)
                    return 2
                }
            case "--no-cleanup":
                cleanup = false
            case "--ollama-model":
                ollamaModel = iterator.next() ?? ollamaModel
            default:
                break
            }
        }

        guard let audioPath else {
            fputs("Usage: LocalFlow --transcribe <audio-file> [--model base.en|small.en|large-v3-turbo] [--no-cleanup] [--ollama-model name]\n", stderr)
            return 2
        }

        do {
            let samples = try AudioFileLoader.loadSamples(from: URL(fileURLWithPath: audioPath))
            print("Loaded \(samples.count) samples (\(String(format: "%.2f", Double(samples.count) / AudioRecorder.sampleRate))s at 16 kHz mono)")

            let manager = ModelManager()
            if !model.isDownloaded {
                print("Downloading \(model.fileName) (\(model.approximateSize))…")
                let progressTask = Task {
                    while !Task.isCancelled {
                        if case .downloading(let progress) = manager.state {
                            print(String(format: "  %.0f%%", progress * 100))
                        }
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
                _ = try await manager.ensureAvailable(model)
                progressTask.cancel()
            }

            let transcriber = WhisperTranscriber()
            print("Loading \(model.rawValue)…")
            try transcriber.load(model: model)

            let start = Date()
            let raw = try transcriber.transcribe(samples: samples)
            let transcript = TranscriptSanitizer.sanitize(raw)
            print(String(format: "Transcribed in %.2fs", Date().timeIntervalSince(start)))
            print("TRANSCRIPT: \(transcript)")

            if CleanupGate.shouldClean(transcript: transcript, cleanupEnabled: cleanup) {
                var config = OllamaConfig()
                config.model = ollamaModel
                print("Cleaning with \(config.model) via Ollama…")
                let outcome = await OllamaCleaner.clean(transcript: transcript, config: config)
                if outcome.fellBack {
                    print("CLEANUP FELL BACK: \(outcome.fallbackReason ?? "unknown")")
                } else {
                    print("CLEANED: \(outcome.text)")
                }
            } else if cleanup {
                print("(cleanup skipped by gate — short transcript or already clean)")
            }
            return 0
        } catch {
            fputs("Error: \(error)\n", stderr)
            return 1
        }
    }
}
