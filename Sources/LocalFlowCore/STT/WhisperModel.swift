import Foundation

/// The ggml Whisper models the user can choose between, downloaded from the
/// official whisper.cpp repository on Hugging Face into Application Support.
public enum WhisperModel: String, CaseIterable, Identifiable {
    case baseEN = "base.en"
    case smallEN = "small.en"
    case largeV3Turbo = "large-v3-turbo"

    public static let `default` = WhisperModel.smallEN

    public var id: String { rawValue }

    public var fileName: String { "ggml-\(rawValue).bin" }

    public var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    public var displayName: String {
        switch self {
        case .baseEN: return "base.en — fastest"
        case .smallEN: return "small.en — balanced (default)"
        case .largeV3Turbo: return "large-v3-turbo — most accurate"
        }
    }

    public var approximateSize: String {
        switch self {
        case .baseEN: return "142 MB"
        case .smallEN: return "466 MB"
        case .largeV3Turbo: return "1.5 GB"
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
