import Foundation
import Testing
@testable import LocalFlowCore

@Suite struct OllamaCleanerTests {

    // MARK: Request building

    @Test func requestTargetsGenerateEndpointWithPOST() throws {
        let request = try OllamaCleaner.makeRequest(transcript: "hello", config: OllamaConfig())
        #expect(request.url?.absoluteString == "http://localhost:11434/api/generate")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func requestBodyContainsModelTranscriptAndNoStreaming() throws {
        var config = OllamaConfig()
        config.model = "gemma3:4b"
        let request = try OllamaCleaner.makeRequest(
            transcript: "um so basically the thing is", config: config
        )
        let httpBody = try #require(request.httpBody)
        let body = try #require(
            try JSONSerialization.jsonObject(with: httpBody) as? [String: Any]
        )
        #expect(body["model"] as? String == "gemma3:4b")
        #expect(body["stream"] as? Bool == false)
        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.contains("um so basically the thing is"))
        // The instruction must forbid answering/summarizing.
        #expect(prompt.lowercased().contains("do not"))
        let options = try #require(body["options"] as? [String: Any])
        #expect(options["temperature"] as? Double == 0)
    }

    @Test func requestUsesConfiguredTimeout() throws {
        var config = OllamaConfig()
        config.timeout = 5
        let request = try OllamaCleaner.makeRequest(transcript: "x", config: config)
        #expect(request.timeoutInterval == 5)
    }

    @Test func requestOmitsPreserveLineWhenListEmpty() throws {
        let request = try OllamaCleaner.makeRequest(
            transcript: "hello", config: OllamaConfig(), preserveList: ""
        )
        let httpBody = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let prompt = try #require(body["prompt"] as? String)
        #expect(!prompt.lowercased().contains("preserve these terms"))
    }

    @Test func requestIncludesPreserveLineWhenListProvided() throws {
        let request = try OllamaCleaner.makeRequest(
            transcript: "hello", config: OllamaConfig(), preserveList: "Claude Code, Kubernetes"
        )
        let httpBody = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.contains("Preserve these terms exactly as written"))
        #expect(prompt.contains("Claude Code, Kubernetes"))
    }

    // MARK: Response parsing

    @Test func parsesResponseField() throws {
        let data = #"{"model":"gemma3:4b","response":"Cleaned sentence.","done":true}"#.data(using: .utf8)!
        #expect(try OllamaCleaner.parseResponse(data: data) == "Cleaned sentence.")
    }

    @Test func missingResponseFieldThrows() {
        let data = #"{"error":"model not found"}"#.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try OllamaCleaner.parseResponse(data: data)
        }
    }

    // MARK: Post-processing of model output

    @Test func postProcessStripsCodeFences() {
        #expect(OllamaCleaner.postProcess("```\nHello, world.\n```") == "Hello, world.")
    }

    @Test func postProcessStripsPreambleLabel() {
        #expect(OllamaCleaner.postProcess("Here is the cleaned text:\nHello, world.") == "Hello, world.")
    }

    @Test func postProcessTrimsWhitespace() {
        #expect(OllamaCleaner.postProcess("  Hello.  \n") == "Hello.")
    }

    @Test func postProcessKeepsParagraphBreaks() {
        let raw = "First paragraph.\n\nSecond paragraph."
        #expect(OllamaCleaner.postProcess(raw) == "First paragraph.\n\nSecond paragraph.")
    }

    @Test func postProcessStripsWrappingQuotes() {
        #expect(OllamaCleaner.postProcess("\"Hello, world.\"") == "Hello, world.")
    }
}
