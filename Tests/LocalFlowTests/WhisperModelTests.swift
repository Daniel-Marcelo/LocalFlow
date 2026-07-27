import Foundation
import Testing
@testable import LocalFlowCore

@Suite struct WhisperModelTests {
    @Test func catalogContainsAllModels() {
        #expect(WhisperModel.allCases.map(\.rawValue) == [
            "base.en", "base.en-q5_1",
            "small.en", "small.en-q5_1",
            "base", "base-q5_1",
            "small", "small-q5_1",
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

    @Test func multilingualModelsExist() {
        #expect(WhisperModel(rawValue: "base") == .base)
        #expect(WhisperModel(rawValue: "base-q5_1") == .baseQ5)
        #expect(WhisperModel(rawValue: "small") == .small)
        #expect(WhisperModel(rawValue: "small-q5_1") == .smallQ5)
    }

    @Test func multilingualModelFileNames() {
        #expect(WhisperModel.base.fileName == "ggml-base.bin")
        #expect(WhisperModel.baseQ5.fileName == "ggml-base-q5_1.bin")
        #expect(WhisperModel.small.fileName == "ggml-small.bin")
        #expect(WhisperModel.smallQ5.fileName == "ggml-small-q5_1.bin")
    }

    @Test func supportedLanguagesForENModels() {
        #expect(WhisperModel.baseEN.supportedLanguages == [.english])
        #expect(WhisperModel.baseENQ5.supportedLanguages == [.english])
        #expect(WhisperModel.smallEN.supportedLanguages == [.english])
        #expect(WhisperModel.smallENQ5.supportedLanguages == [.english])
    }

    @Test func supportedLanguagesForMultilingualModels() {
        #expect(WhisperModel.base.supportedLanguages == [.portugueseBR])
        #expect(WhisperModel.baseQ5.supportedLanguages == [.portugueseBR])
        #expect(WhisperModel.small.supportedLanguages == [.portugueseBR])
        #expect(WhisperModel.smallQ5.supportedLanguages == [.portugueseBR])
    }

    @Test func supportedLanguagesForTurboModels() {
        #expect(WhisperModel.largeV3Turbo.supportedLanguages == [.english, .portugueseBR])
        #expect(WhisperModel.largeV3TurboQ5.supportedLanguages == [.english, .portugueseBR])
    }

    @Test func modelsForEnglishReturnsENAndTurbo() {
        let models = WhisperModel.models(for: .english)
        #expect(models.contains(.baseEN))
        #expect(models.contains(.smallEN))
        #expect(models.contains(.largeV3Turbo))
        #expect(!models.contains(.base))
        #expect(!models.contains(.small))
    }

    @Test func modelsForPortugueseReturnsMultilingualAndTurbo() {
        let models = WhisperModel.models(for: .portugueseBR)
        #expect(models.contains(.base))
        #expect(models.contains(.small))
        #expect(models.contains(.largeV3Turbo))
        #expect(!models.contains(.baseEN))
        #expect(!models.contains(.smallEN))
    }

    @Test func defaultForEnglishIsSmallEN() {
        #expect(WhisperModel.default(for: .english) == .smallEN)
    }

    @Test func defaultForPortugueseIsSmall() {
        #expect(WhisperModel.default(for: .portugueseBR) == .small)
    }
}
