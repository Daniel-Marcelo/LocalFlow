import AVFoundation

/// Loads an audio file and converts it to Whisper's 16 kHz mono Float32
/// format. Used by the `--transcribe` CLI mode and by tests; exercises the
/// same target format as the live microphone path.
public enum AudioFileLoader {
    public static func loadSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        guard let converter = AVAudioConverter(from: sourceFormat, to: AudioRecorder.targetFormat) else {
            throw AudioRecorderError.converterUnavailable
        }

        let sourceCapacity: AVAudioFrameCount = 8192
        var samples: [Float] = []
        var reachedEnd = false

        while !reachedEnd {
            let ratio = AudioRecorder.sampleRate / sourceFormat.sampleRate
            let outCapacity = AVAudioFrameCount(Double(sourceCapacity) * ratio) + 32
            guard let out = AVAudioPCMBuffer(
                pcmFormat: AudioRecorder.targetFormat, frameCapacity: outCapacity
            ) else {
                throw AudioRecorderError.converterUnavailable
            }
            var readError: Error?
            var status: AVAudioConverterOutputStatus = .haveData
            var conversionError: NSError?
            status = converter.convert(to: out, error: &conversionError) { _, outStatus in
                // AVAudioFile.read(into:) throws a spurious error when called
                // at EOF (rather than returning an empty buffer), so check the
                // position explicitly.
                guard file.framePosition < file.length,
                      let inBuffer = AVAudioPCMBuffer(
                          pcmFormat: sourceFormat, frameCapacity: sourceCapacity
                      )
                else {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                do {
                    try file.read(into: inBuffer)
                } catch {
                    readError = error
                }
                if inBuffer.frameLength == 0 {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                outStatus.pointee = .haveData
                return inBuffer
            }
            if let readError { throw readError }
            if let conversionError { throw conversionError }
            if out.frameLength > 0, let channel = out.floatChannelData {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
            }
            reachedEnd = (status == .endOfStream || status == .error || out.frameLength == 0)
        }
        return samples
    }
}
