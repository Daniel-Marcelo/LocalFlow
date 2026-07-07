import Foundation

/// The ggml Whisper models the user can choose between, downloaded from the
/// official whisper.cpp repository on Hugging Face into Application Support.
public enum WhisperModel: String, CaseIterable, Identifiable {
    case baseEN = "base.en"
    case baseENQ5 = "base.en-q5_1"
    case smallEN = "small.en"
    case smallENQ5 = "small.en-q5_1"
    case largeV3Turbo = "large-v3-turbo"
    case largeV3TurboQ5 = "large-v3-turbo-q5_0"

    public static let `default` = WhisperModel.smallEN

    public var id: String { rawValue }

    public var fileName: String { "ggml-\(rawValue).bin" }

    public var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    public var displayName: String {
        switch self {
        case .baseEN: return "base.en — fastest"
        case .baseENQ5: return "base.en q5 — fastest, quantized"
        case .smallEN: return "small.en — balanced (default)"
        case .smallENQ5: return "small.en q5 — balanced, quantized"
        case .largeV3Turbo: return "large-v3-turbo — most accurate"
        case .largeV3TurboQ5: return "large-v3-turbo q5 — accurate, quantized"
        }
    }

    public var approximateSize: String {
        switch self {
        case .baseEN: return "148 MB"
        case .baseENQ5: return "60 MB"
        case .smallEN: return "488 MB"
        case .smallENQ5: return "190 MB"
        case .largeV3Turbo: return "1.6 GB"
        case .largeV3TurboQ5: return "574 MB"
        }
    }

    public static var modelsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalFlow/models", isDirectory: true)
    }

    public var localURL: URL {
        Self.modelsDirectory.appendingPathComponent(fileName)
    }

    public var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }
}
