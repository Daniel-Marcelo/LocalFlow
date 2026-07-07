import Foundation
import Testing
@testable import LocalFlowCore

@Suite struct WhisperModelTests {
    @Test func catalogContainsTheThreeSpecModels() {
        #expect(WhisperModel.allCases.map(\.rawValue) == ["base.en", "small.en", "large-v3-turbo"])
    }

    @Test func defaultModelIsSmallEN() {
        #expect(WhisperModel.default == .smallEN)
    }

    @Test func fileNames() {
        #expect(WhisperModel.baseEN.fileName == "ggml-base.en.bin")
        #expect(WhisperModel.smallEN.fileName == "ggml-small.en.bin")
        #expect(WhisperModel.largeV3Turbo.fileName == "ggml-large-v3-turbo.bin")
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
