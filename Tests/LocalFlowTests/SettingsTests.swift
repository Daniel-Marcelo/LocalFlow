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

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.hotkey == .f13)
        #expect(reloaded.activationMode == .toggle)
        #expect(reloaded.whisperModel == .largeV3Turbo)
        #expect(!reloaded.cleanupEnabled)
        #expect(reloaded.ollamaModel == "llama3.2:3b")
        #expect(reloaded.injectionMethod == .type)
        #expect(!reloaded.hudEnabled)
        #expect(!reloaded.soundCuesEnabled)
    }

    @Test func garbageStoredValuesFallBackToDefaults() {
        let defaults = freshDefaults("garbage")
        defaults.set("not-a-real-key", forKey: "hotkey")
        defaults.set("not-a-real-model", forKey: "whisperModel")
        let settings = Settings(defaults: defaults)
        #expect(settings.hotkey == .rightOption)
        #expect(settings.whisperModel == .smallEN)
    }
}
