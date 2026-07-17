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
    private lazy var session = URLSession(
        configuration: .default, delegate: self, delegateQueue: nil
    )

    private struct PendingDownload {
        let model: WhisperModel
        let continuation: CheckedContinuation<URL, Error>
    }

    /// Guards `pending` and `inFlight`. Delegate callbacks arrive on a
    /// background queue, so this state can't live on a single actor.
    private let lock = NSLock()
    /// Active downloads keyed by `URLSessionTask.taskIdentifier`, so each
    /// delegate callback resolves *its own* continuation — never a sibling's.
    private var pending: [Int: PendingDownload] = [:]
    /// One coalesced download Task per model, so concurrent `ensureAvailable`
    /// calls for the same model share a single request instead of racing.
    private var inFlight: [WhisperModel: Task<URL, Error>] = [:]

    /// Returns the local model path, downloading first if needed.
    /// Progress is published on `state` for the settings UI / menu.
    /// Concurrent calls are safe: requests for the same model are coalesced,
    /// and each download's completion is matched to its own request.
    public func ensureAvailable(_ model: WhisperModel) async throws -> URL {
        if model.isDownloaded {
            return model.localURL
        }
        let task: Task<URL, Error> = {
            lock.lock()
            defer { lock.unlock() }
            if let existing = inFlight[model] { return existing }
            let task = Task { try await self.performDownload(model) }
            inFlight[model] = task
            return task
        }()
        return try await task.value
    }

    private func performDownload(_ model: WhisperModel) async throws -> URL {
        defer {
            lock.lock()
            inFlight[model] = nil
            lock.unlock()
        }
        try FileManager.default.createDirectory(
            at: WhisperModel.modelsDirectory, withIntermediateDirectories: true
        )
        log.info("Downloading \(model.fileName, privacy: .public) (\(model.approximateSize, privacy: .public))")
        await MainActor.run { state = .downloading(progress: 0) }
        do {
            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let task = session.downloadTask(with: model.downloadURL)
                lock.lock()
                pending[task.taskIdentifier] = PendingDownload(model: model, continuation: continuation)
                lock.unlock()
                task.resume()
            }
            await MainActor.run { state = .idle }
            return url
        } catch {
            await MainActor.run { state = .failed(error.localizedDescription) }
            throw error
        }
    }

    /// Resumes (exactly once) the continuation for a finished task.
    private func finish(taskID: Int, with result: Result<URL, Error>) {
        lock.lock()
        let entry = pending.removeValue(forKey: taskID)
        lock.unlock()
        entry?.continuation.resume(with: result)
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
        // `location` is only valid until this method returns, so move the file
        // synchronously here rather than hopping to another queue.
        lock.lock()
        let model = pending[downloadTask.taskIdentifier]?.model
        lock.unlock()
        guard let model else { return }
        do {
            if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            let destination = model.localURL
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            finish(taskID: downloadTask.taskIdentifier, with: .success(destination))
        } catch {
            finish(taskID: downloadTask.taskIdentifier, with: .failure(error))
        }
    }

    public func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        // Success is handled in didFinishDownloadingTo; here we only need to
        // surface a transport failure (the success case already removed the
        // entry, so this is a no-op then).
        if let error {
            finish(taskID: task.taskIdentifier, with: .failure(error))
        }
    }
}
