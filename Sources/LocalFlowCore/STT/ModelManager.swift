import Foundation
import os.log

/// Downloads ggml Whisper models from the official whisper.cpp Hugging Face
/// repository into Application Support, reporting progress for the UI.
/// After the one-time download everything is fully offline.
public final class ModelManager: NSObject, ObservableObject {
    public enum DownloadState: Equatable {
        case idle
        case downloading(progress: Double)
        case failed(String)
    }

    @Published public private(set) var state: DownloadState = .idle

    private let log = Logger(subsystem: "com.localflow.app", category: "models")
    private var continuation: CheckedContinuation<URL, Error>?
    private var currentModel: WhisperModel?
    private lazy var session = URLSession(
        configuration: .default, delegate: self, delegateQueue: nil
    )

    /// Returns the local model path, downloading first if needed.
    /// Progress is published on `state` for the settings UI / menu.
    public func ensureAvailable(_ model: WhisperModel) async throws -> URL {
        if model.isDownloaded {
            return model.localURL
        }
        try FileManager.default.createDirectory(
            at: WhisperModel.modelsDirectory, withIntermediateDirectories: true
        )
        log.info("Downloading \(model.fileName, privacy: .public) (\(model.approximateSize, privacy: .public))")
        await MainActor.run { state = .downloading(progress: 0) }
        do {
            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                self.continuation = continuation
                self.currentModel = model
                self.session.downloadTask(with: model.downloadURL).resume()
            }
            await MainActor.run { state = .idle }
            return url
        } catch {
            await MainActor.run { state = .failed(error.localizedDescription) }
            throw error
        }
    }
}

extension ModelManager: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.state = .downloading(progress: progress) }
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let model = currentModel else { return }
        do {
            if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            let destination = model.localURL
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume(returning: destination)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
        currentModel = nil
    }

    public func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            currentModel = nil
        }
    }
}
