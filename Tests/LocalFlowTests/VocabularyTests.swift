import Foundation
import Testing
@testable import LocalFlowCore

@Suite struct VocabularyTests {

    // MARK: Normalization

    @Test func dropsEmptyAndDuplicateTermsAndTrims() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "  Kubernetes  ", variants: []),
            VocabularyEntry(term: "", variants: ["ignored"]),
            VocabularyEntry(term: "kubernetes", variants: ["k8s"]),   // dup term, first-wins
        ])
        #expect(vocab.entries.map(\.term) == ["Kubernetes"])
    }

    @Test func dropsEmptySelfReferentialAndDuplicateVariants() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "Claude Code",
                            variants: ["  ", "claude code", "clod code", "clod code"])
        ])
        #expect(vocab.entries.first?.variants == ["clod code"])
    }

    // MARK: Priming

    @Test func primingPromptJoinsCanonicalTerms() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "Claude Code", variants: ["clod code"]),
            VocabularyEntry(term: "Kubernetes", variants: []),
        ])
        #expect(vocab.primingPrompt == "Claude Code, Kubernetes")
        #expect(vocab.droppedFromPriming == 0)
    }

    @Test func primingPromptEmptyForEmptyVocabulary() {
        let vocab = Vocabulary(entries: [])
        #expect(vocab.primingPrompt == "")
        #expect(vocab.droppedFromPriming == 0)
    }

    @Test func primingPromptRespectsBudgetAndReportsDropped() {
        let entries = (0..<200).map { VocabularyEntry(term: "Term\($0)", variants: []) }
        let vocab = Vocabulary(entries: entries)
        #expect(vocab.primingPrompt.count <= Vocabulary.primingCharacterBudget)
        #expect(vocab.droppedFromPriming > 0)
        let included = vocab.primingPrompt.split(separator: ",").count
        #expect(included + vocab.droppedFromPriming == 200)
    }

    // MARK: Replacement

    @Test func replacesVariantWithCanonicalCaseInsensitively() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "Claude Code", variants: ["clod code", "cloud code"])
        ])
        #expect(vocab.applyReplacements("I love clod code.") == "I love Claude Code.")
        #expect(vocab.applyReplacements("Using CLOUD CODE daily") == "Using Claude Code daily")
    }

    @Test func replacementRespectsWordBoundaries() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "Art", variants: ["arte"])
        ])
        #expect(vocab.applyReplacements("the arte") == "the Art")
        #expect(vocab.applyReplacements("cartel") == "cartel")   // "arte" inside a word: no match
    }

    @Test func prefersLongestVariantOnOverlap() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "Claude Code", variants: ["clod code"]),
            VocabularyEntry(term: "Claude", variants: ["clod"]),
        ])
        #expect(vocab.applyReplacements("run clod code now") == "run Claude Code now")
    }

    @Test func escapesRegexMetacharactersInVariants() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "C++", variants: ["c plus plus", "c.plus.plus"])
        ])
        #expect(vocab.applyReplacements("I code in c plus plus") == "I code in C++")
        #expect(vocab.applyReplacements("c.plus.plus rocks") == "C++ rocks")
        #expect(vocab.applyReplacements("cxplusxplus") == "cxplusxplus")   // '.' is literal
    }

    @Test func doesNotCascadeAcrossRules() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "beta", variants: ["alpha"]),
            VocabularyEntry(term: "gamma", variants: ["beta"]),
        ])
        #expect(vocab.applyReplacements("alpha") == "beta")   // not re-applied to "gamma"
        #expect(vocab.applyReplacements("beta") == "gamma")
    }

    @Test func firstWinsOnConflictingVariant() {
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "Foo", variants: ["thing"]),
            VocabularyEntry(term: "Bar", variants: ["thing"]),
        ])
        #expect(vocab.applyReplacements("a thing") == "a Foo")
    }

    @Test func emptyVocabularyIsIdentity() {
        #expect(Vocabulary(entries: []).applyReplacements("nothing to do") == "nothing to do")
    }

    // MARK: Preserve list

    @Test func preserveListJoinsTermsAndIsEmptyWhenNoTerms() {
        #expect(Vocabulary(entries: []).preserveList == "")
        let vocab = Vocabulary(entries: [
            VocabularyEntry(term: "Kubernetes", variants: []),
            VocabularyEntry(term: "Claude Code", variants: ["clod code"]),
        ])
        #expect(vocab.preserveList == "Kubernetes, Claude Code")
    }
}
