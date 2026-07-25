import Testing
@testable import LocalFlowCore

@Suite struct DictationLanguageTests {
    @Test func rawValuesMatchWhisperCodes() {
        #expect(DictationLanguage.english.rawValue == "en")
        #expect(DictationLanguage.portugueseBR.rawValue == "pt")
    }

    @Test func whisperCodeEqualsRawValue() {
        for lang in DictationLanguage.allCases {
            #expect(lang.whisperCode == lang.rawValue)
        }
    }

    @Test func displayNames() {
        #expect(DictationLanguage.english.displayName == "English")
        #expect(DictationLanguage.portugueseBR.displayName == "Português (Brasil)")
    }

    @Test func defaultIsEnglish() {
        #expect(DictationLanguage.default == .english)
    }

    @Test func identifiableIdIsRawValue() {
        for lang in DictationLanguage.allCases {
            #expect(lang.id == lang.rawValue)
        }
    }

    @Test func roundTripFromRawValue() {
        #expect(DictationLanguage(rawValue: "en") == .english)
        #expect(DictationLanguage(rawValue: "pt") == .portugueseBR)
        #expect(DictationLanguage(rawValue: "garbage") == nil)
    }
}
