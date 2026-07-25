import Foundation
import Testing
@testable import LocalFlowCore

/// Each test uses its own suite so parallel test execution can't interleave.
private func freshDefaults(_ name: String) -> UserDefaults {
    let suite = "LocalFlowTests-\(name)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@Suite struct SettingsTests {
    @Test func freshDefaultsMatchSpec() {
        let settings = Settings(defaults: freshDefaults("fresh"))
        #expect(settings.hotkey == .rightOption)
        #expect(settings.activationMode == .hold)
        #expect(settings.whisperModel == .smallEN)
        #expect(settings.cleanupEnabled)
        #expect(settings.ollamaModel == "gemma3:4b")
        #expect(settings.injectionMethod == .paste)
        #expect(settings.hudEnabled)
        #expect(settings.soundCuesEnabled)
        #expect(settings.hudSize == .standard)
        #expect(settings.hudStyle == .system)
        #expect(settings.hudBehavior == .fullPipeline)
    }

    @Test func valuesPersistAcrossInstances() {
        let defaults = freshDefaults("persist")
        let settings = Settings(defaults: defaults)
        settings.hotkey = .f13
        settings.activationMode = .toggle
        settings.whisperModel = .largeV3Turbo
        settings.cleanupEnabled = false
        settings.ollamaModel = "llama3.2:3b"
        settings.injectionMethod = .type
        settings.hudEnabled = false
        settings.soundCuesEnabled = false
        settings.hudSize = .large
        settings.hudStyle = .vibrant
        settings.hudBehavior = .recordingOnly

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.hotkey == .f13)
        #expect(reloaded.activationMode == .toggle)
        #expect(reloaded.whisperModel == .largeV3Turbo)
        #expect(!reloaded.cleanupEnabled)
        #expect(reloaded.ollamaModel == "llama3.2:3b")
        #expect(reloaded.injectionMethod == .type)
        #expect(!reloaded.hudEnabled)
        #expect(!reloaded.soundCuesEnabled)
        #expect(reloaded.hudSize == .large)
        #expect(reloaded.hudStyle == .vibrant)
        #expect(reloaded.hudBehavior == .recordingOnly)
    }

    @Test func garbageStoredValuesFallBackToDefaults() {
        let defaults = freshDefaults("garbage")
        defaults.set("not-a-real-key", forKey: "hotkey")
        defaults.set("not-a-real-model", forKey: "whisperModel")
        let settings = Settings(defaults: defaults)
        #expect(settings.hotkey == .rightOption)
        #expect(settings.whisperModel == .smallEN)
    }

    @Test func vocabularyDefaultsToEmpty() {
        let settings = Settings(defaults: freshDefaults("vocab-empty"))
        #expect(settings.vocabulary.isEmpty)
    }

    @Test func vocabularyPersistsAcrossInstances() {
        let defaults = freshDefaults("vocab-persist")
        let settings = Settings(defaults: defaults)
        settings.vocabulary = [
            VocabularyEntry(term: "Claude Code", variants: ["clod code"]),
            VocabularyEntry(term: "Kubernetes", variants: []),
        ]
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.vocabulary == settings.vocabulary)
        #expect(reloaded.vocabulary.map(\.term) == ["Claude Code", "Kubernetes"])
    }

    @Test func garbageVocabularyFallsBackToEmpty() {
        let defaults = freshDefaults("vocab-garbage")
        defaults.set("not json", forKey: "vocabulary")
        let settings = Settings(defaults: defaults)
        #expect(settings.vocabulary.isEmpty)
    }

    @Test func languageDefaultsToEnglish() {
        let settings = Settings(defaults: freshDefaults("lang-default"))
        #expect(settings.language == .english)
    }

    @Test func languagePersistsAndRoundTrips() {
        let defaults = freshDefaults("lang-persist")
        let settings = Settings(defaults: defaults)
        settings.language = .portugueseBR
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.language == .portugueseBR)
    }

    @Test func languageGarbageFallsBackToDefault() {
        let defaults = freshDefaults("lang-garbage")
        defaults.set("xx", forKey: "language")
        let settings = Settings(defaults: defaults)
        #expect(settings.language == .english)
    }

    @Test func perLanguageModelIsolation() {
        let settings = Settings(defaults: freshDefaults("lang-model-iso"))
        settings.setWhisperModel(.largeV3Turbo, for: .english)
        settings.setWhisperModel(.small, for: .portugueseBR)
        #expect(settings.whisperModel(for: .english) == .largeV3Turbo)
        #expect(settings.whisperModel(for: .portugueseBR) == .small)
    }

    @Test func whisperModelConvenienceReadsActiveLanguage() {
        let settings = Settings(defaults: freshDefaults("lang-convenience"))
        settings.language = .portugueseBR
        settings.setWhisperModel(.baseQ5, for: .portugueseBR)
        #expect(settings.whisperModel == .baseQ5)
    }

    @Test func whisperModelConvenienceWritesActiveLanguage() {
        let settings = Settings(defaults: freshDefaults("lang-conv-write"))
        settings.language = .portugueseBR
        settings.whisperModel = .small
        #expect(settings.whisperModel(for: .portugueseBR) == .small)
        #expect(settings.whisperModel(for: .english) == .smallEN)
    }

    @Test func unsupportedPersistedModelFallsBackToLanguageDefault() {
        let defaults = freshDefaults("lang-model-unsupported")
        defaults.set("base.en", forKey: "whisperModel.pt")
        let settings = Settings(defaults: defaults)
        #expect(settings.whisperModel(for: .portugueseBR) == .small)
    }

    @Test func migrationSeedsENFromLegacyFlatKey() {
        let defaults = freshDefaults("lang-migration")
        defaults.set("large-v3-turbo", forKey: "whisperModel")
        let settings = Settings(defaults: defaults)
        #expect(settings.whisperModel(for: .english) == .largeV3Turbo)
        #expect(defaults.string(forKey: "whisperModel.en") == "large-v3-turbo")
    }

    @Test func migrationDoesNotOverwriteExistingENKey() {
        let defaults = freshDefaults("lang-migration-no-overwrite")
        defaults.set("large-v3-turbo", forKey: "whisperModel")
        defaults.set("base.en", forKey: "whisperModel.en")
        let settings = Settings(defaults: defaults)
        #expect(settings.whisperModel(for: .english) == .baseEN)
        #expect(defaults.string(forKey: "whisperModel.en") == "base.en")
    }
}
