import Foundation
import os.log

public struct OllamaConfig {
    public var baseURL = URL(string: "http://localhost:11434")!
    public var model = "gemma3:4b"
    /// Seconds before the cleanup request is abandoned in favor of the raw
    /// transcript. A dead Ollama fails instantly (connection refused); this
    /// only bites when the daemon is up but slow, so it's sized for a cold
    /// gemma3:4b load rather than for snappiness — the app's launch warm-up
    /// keeps the common case fast.
    public var timeout: TimeInterval = 15

    public init() {}
}

public enum OllamaError: Error {
    case malformedResponse
}

/// The result of the cleanup stage. `fellBack` distinguishes "Ollama cleaned
/// it" from "Ollama was down/slow, this is the raw transcript" so the UI can
/// surface a non-blocking warning.
public struct CleanupOutcome {
    public let text: String
    public let fellBack: Bool
    public let fallbackReason: String?
}

public enum OllamaCleaner {
    private static let log = Logger(subsystem: "com.localflow.app", category: "ollama")

    private static let englishInstruction = """
    You clean up dictated speech transcripts. Rewrite the transcript below by:
    - Removing filler words (um, uh, you know, like, I mean, actually).
    - Removing false starts and self-corrections, keeping only the corrected version.
    - Fixing grammar, capitalization, and punctuation.
    - Splitting the text into logical paragraphs where appropriate.

    Do NOT add anything, do not summarize, do not answer questions in the \
    text, and do not translate — keep the input language. Output only the \
    cleaned version of the transcript, with no preamble and no quotation \
    marks around it.
    """

    private static let portugueseInstruction = """
    Você limpa transcrições de fala ditada. Reescreva a transcrição abaixo:
    - Removendo palavras de preenchimento (é, tipo, né, então, sabe, aí).
    - Removendo falsos inícios e autocorreções, mantendo apenas a versão corrigida.
    - Corrigindo gramática, acentuação, maiúsculas e pontuação.
    - Dividindo o texto em parágrafos lógicos quando fizer sentido.

    NÃO adicione nada, não resuma, não responda perguntas contidas no texto e \
    não traduza — mantenha o idioma original. Produza apenas a versão limpa da \
    transcrição, sem preâmbulo e sem aspas ao redor.
    """

    public static func instructionTemplate(for language: DictationLanguage) -> String {
        switch language {
        case .english: return englishInstruction
        case .portugueseBR: return portugueseInstruction
        }
    }

    private static func preserveInstruction(for language: DictationLanguage, terms: String) -> String {
        switch language {
        case .english:
            return "Preserve these terms exactly as written; do not change their spelling: \(terms)."
        case .portugueseBR:
            return "Mantenha os seguintes termos exatamente como estão escritos, sem alterar a grafia: \(terms)."
        }
    }

    private static func transcriptLabel(for language: DictationLanguage) -> String {
        switch language {
        case .english: return "Transcript:"
        case .portugueseBR: return "Transcrição:"
        }
    }

    // MARK: Request / response plumbing (pure, unit-tested)

    public static func makeRequest(
        transcript: String, config: OllamaConfig, preserveList: String = "",
        language: DictationLanguage = .english
    ) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeout

        var prompt = instructionTemplate(for: language)
        if !preserveList.isEmpty {
            prompt += "\n" + preserveInstruction(for: language, terms: preserveList)
        }
        prompt += "\n\n" + transcriptLabel(for: language) + "\n" + transcript

        let body: [String: Any] = [
            "model": config.model,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": 0.0],
            // Keep the model resident between dictations so cleanup stays fast.
            "keep_alive": "30m",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func parseResponse(data: Data) throws -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let response = object["response"] as? String
        else {
            throw OllamaError.malformedResponse
        }
        return response
    }

    /// Defensive cleanup of LLM output: strip code fences, a "here is the
    /// cleaned text:" style preamble line, and wrapping quotes.
    public static func postProcess(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("```") && text.hasSuffix("```") {
            text = text
                .replacingOccurrences(of: "^```[a-z]*\\n?", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\n?```$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lines = text.components(separatedBy: "\n")
        let preamblePatterns = [
            "^(sure[,!. ]*)?(okay[,!. ]*)?(here('s| is)? )?(the )?(cleaned|corrected|revised)[^:]*: *$",
            "^(aqui (está|vai)|segue|versão|texto)\\b[^:]*: *$",
        ]
        if let first = lines.first,
           preamblePatterns.contains(where: {
               first.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
           }) {
            text = lines.dropFirst().joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
        }

        return text
    }

    // MARK: Live call

    /// Runs the transcript through Ollama. Never throws: any failure
    /// (unreachable daemon, timeout, bad payload, empty output) falls back to
    /// the raw transcript so dictation keeps working with the LLM stage down.
    public static func clean(
        transcript: String, config: OllamaConfig, preserveList: String = "",
        language: DictationLanguage = .english
    ) async -> CleanupOutcome {
        let request: URLRequest
        do {
            request = try makeRequest(
                transcript: transcript, config: config,
                preserveList: preserveList, language: language
            )
        } catch {
            return CleanupOutcome(text: transcript, fellBack: true, fallbackReason: "\(error)")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let detail = String(data: data, encoding: .utf8) ?? ""
                log.error("Ollama returned \(http.statusCode): \(detail, privacy: .public)")
                return CleanupOutcome(
                    text: transcript, fellBack: true,
                    fallbackReason: "Ollama returned HTTP \(http.statusCode)"
                )
            }
            let cleaned = postProcess(try parseResponse(data: data))
            guard !cleaned.isEmpty else {
                return CleanupOutcome(
                    text: transcript, fellBack: true, fallbackReason: "Ollama returned empty text"
                )
            }
            return CleanupOutcome(text: cleaned, fellBack: false, fallbackReason: nil)
        } catch {
            log.error("Ollama request failed: \(error.localizedDescription, privacy: .public)")
            return CleanupOutcome(
                text: transcript, fellBack: true,
                fallbackReason: "Ollama unreachable or timed out"
            )
        }
    }

    /// Fire-and-forget warm-up so the first real dictation doesn't pay the
    /// model-load cost. A prompt-less request makes Ollama load the model only.
    public static func warmUp(config: OllamaConfig) {
        let url = config.baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": config.model,
            "keep_alive": "30m",
        ])
        URLSession.shared.dataTask(with: request).resume()
    }
}
