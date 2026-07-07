import Foundation
import Testing
@testable import LocalFlowCore

@Suite struct WhisperModelTests {
    @Test func catalogContainsSpecModelsPlusQuantizedVariants() {
        #expect(WhisperModel.allCases.map(\.rawValue) == [
            "base.en", "base.en-q5_1",
            "small.en", "small.en-q5_1",
            "large-v3-turbo", "large-v3-turbo-q5_0",
        ])
    }

    @Test func defaultModelIsSmallEN() {
        #expect(WhisperModel.default == .smallEN)
    }

    @Test func fileNames() {
        #expect(WhisperModel.baseEN.fileName == "ggml-base.en.bin")
        #expect(WhisperModel.smallEN.fileName == "ggml-small.en.bin")
        #expect(WhisperModel.largeV3Turbo.fileName == "ggml-large-v3-turbo.bin")
        #expect(WhisperModel.baseENQ5.fileName == "ggml-base.en-q5_1.bin")
        #expect(WhisperModel.smallENQ5.fileName == "ggml-small.en-q5_1.bin")
        #expect(WhisperModel.largeV3TurboQ5.fileName == "ggml-large-v3-turbo-q5_0.bin")
    }

    @Test func downloadURLsPointAtOfficialWhisperCppHuggingFaceRepo() {
        for model in WhisperModel.allCases {
            let url = model.downloadURL.absoluteString
            #expect(url.hasPrefix("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"))
            #expect(url.hasSuffix(model.fileName))
        }
    }

    @Test func localURLLivesInApplicationSupportLocalFlowModels() {
        let path = WhisperModel.smallEN.localURL.path
        #expect(path.contains("Application Support/LocalFlow/models"))
        #expect(path.hasSuffix("ggml-small.en.bin"))
    }
}
