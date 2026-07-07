import AVFoundation
import os.log

public enum AudioRecorderError: Error, LocalizedError {
    case noInputDevice
    case converterUnavailable

    public var errorDescription: String? {
        switch self {
        case .noInputDevice: return "No microphone input device available"
        case .converterUnavailable: return "Could not create audio converter"
        }
    }
}

/// Captures microphone audio while the hotkey is held and accumulates it as
/// 16 kHz mono Float32 PCM — the only format Whisper accepts. The device's
/// native format (typically 48 kHz) is resampled on the fly with
/// AVAudioConverter.
public final class AudioRecorder {
    public static let sampleRate = 16_000.0

    public static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
    )!

    private let log = Logger(subsystem: "com.localflow.app", category: "audio")
    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private let sampleQueue = DispatchQueue(label: "com.localflow.audio-samples")
    private var samples: [Float] = []

    public private(set) var isRecording = false

    public init() {}

    public func start() throws {
        guard !isRecording else { return }
        sampleQueue.sync { samples.removeAll(keepingCapacity: true) }

        // A fresh engine each recording picks up input-device changes
        // (AirPods connected, USB mic unplugged, …) since the last run.
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioRecorderError.noInputDevice
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat) else {
            throw AudioRecorderError.converterUnavailable
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.appendResampled(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        self.engine = engine
        isRecording = true
        log.debug("Recording started at \(inputFormat.sampleRate, privacy: .public) Hz")
    }

    /// Stops the engine and returns everything captured, as 16 kHz mono PCM.
    @discardableResult
    public func stop() -> [Float] {
        guard isRecording, let engine else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        converter = nil
        isRecording = false
        return sampleQueue.sync {
            let captured = samples
            samples = []
            log.debug("Recording stopped: \(captured.count) samples (\(Double(captured.count) / Self.sampleRate, format: .fixed(precision: 2))s)")
            return captured
        }
    }

    private func appendResampled(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = Self.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: capacity) else {
            return
        }
        var fed = false
        var conversionError: NSError?
        converter.convert(to: out, error: &conversionError) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        if conversionError == nil, out.frameLength > 0, let channel = out.floatChannelData {
            let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
            sampleQueue.async { self.samples.append(contentsOf: chunk) }
        }
    }
}
