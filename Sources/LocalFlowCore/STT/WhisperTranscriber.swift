import Foundation
import whisper
import os.log

public enum WhisperError: Error, LocalizedError {
    case modelLoadFailed(String)
    case notLoaded
    case transcriptionFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path): return "Failed to load Whisper model at \(path)"
        case .notLoaded: return "No Whisper model is loaded"
        case .transcriptionFailed(let code): return "whisper_full failed with code \(code)"
        }
    }
}

/// Thin wrapper around the whisper.cpp C API. Loads a ggml model once
/// (with the Metal backend when available) and transcribes 16 kHz mono
/// Float32 buffers. Not thread-safe; the pipeline serializes access.
public final class WhisperTranscriber {
    private let log = Logger(subsystem: "com.localflow.app", category: "whisper")
    private var context: OpaquePointer?
    public private(set) var loadedModel: WhisperModel?

    /// Utterances shorter than this are treated as accidental taps.
    public static let minimumUtteranceSeconds = 0.25
    /// whisper_full rejects buffers under ~1 s; shorter real utterances are
    /// padded with trailing silence up to this length.
    static let minimumBufferSeconds = 1.1

    public init() {}

    deinit {
        unload()
    }

    public func load(model: WhisperModel) throws {
        if loadedModel == model, context != nil { return }
        unload()
        var params = whisper_context_default_params()
        params.use_gpu = true
        // Flash attention: measurably faster on Metal with identical output.
        params.flash_attn = true
        let path = model.localURL.path
        guard let context = whisper_init_from_file_with_params(path, params) else {
            throw WhisperError.modelLoadFailed(path)
        }
        self.context = context
        loadedModel = model
        log.info("Loaded Whisper model \(model.rawValue, privacy: .public)")
    }

    public func unload() {
        if let context {
            whisper_free(context)
        }
        context = nil
        loadedModel = nil
    }

    /// Transcribes a 16 kHz mono Float32 buffer. Returns the raw Whisper text
    /// (unsanitized). Returns "" for buffers too short to be real speech.
    public func transcribe(samples: [Float], initialPrompt: String = "") throws -> String {
        guard let context else { throw WhisperError.notLoaded }

        let seconds = Double(samples.count) / AudioRecorder.sampleRate
        guard seconds >= Self.minimumUtteranceSeconds else { return "" }

        var padded = samples
        let minimumCount = Int(Self.minimumBufferSeconds * AudioRecorder.sampleRate)
        if padded.count < minimumCount {
            padded.append(contentsOf: [Float](repeating: 0, count: minimumCount - padded.count))
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_special = false
        params.print_timestamps = false
        params.no_timestamps = true
        params.translate = false
        params.suppress_blank = true
        params.n_threads = Int32(max(2, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))

        let start = Date()
        func run(_ params: whisper_full_params) -> Int32 {
            var params = params
            return "en".withCString { english in
                params.language = english
                return padded.withUnsafeBufferPointer { buffer in
                    whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }

        let status: Int32
        if initialPrompt.isEmpty {
            status = run(params)
        } else {
            status = initialPrompt.withCString { prompt in
                var params = params
                params.initial_prompt = prompt
                return run(params)
            }
        }
        guard status == 0 else { throw WhisperError.transcriptionFailed(status) }

        var text = ""
        for index in 0..<whisper_full_n_segments(context) {
            if let segment = whisper_full_get_segment_text(context, index) {
                text += String(cString: segment)
            }
        }
        let elapsed = Date().timeIntervalSince(start)
        log.info("Transcribed \(seconds, format: .fixed(precision: 2))s of audio in \(elapsed, format: .fixed(precision: 2))s")
        return text
    }

    /// Quiets whisper.cpp / ggml logging (they write verbosely to stderr by
    /// default). Call once at app startup; skip for CLI debugging runs.
    public static func silenceLogging() {
        whisper_log_set({ _, _, _ in }, nil)
    }
}
