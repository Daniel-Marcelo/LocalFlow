# Task 1: Vocabulary Model

Self-contained. You need only this file and the repository.

## Context

This task creates the pure, testable core of the custom-vocabulary feature. No
UI, no Settings, no pipeline wiring yet — later tasks consume the types you
define here.

One combined list drives two mechanisms:
- **Priming:** the canonical terms are joined into a string later fed to Whisper
  as `initial_prompt` (biases recognition). Capped to a character budget because
  Whisper silently truncates past ~224 tokens.
- **Replacement:** each *variant* (a way Whisper mishears a term) is
  deterministically rewritten to its canonical term, in a single left-to-right
  pass so one rule can never re-match another rule's output.

**Global constraints:** Swift 6.1, language mode v5, macOS 14+. Everything in the
`LocalFlowCore` module. Tests use **Swift Testing** (`import Testing`), run via
`./scripts/test.sh --filter VocabularyTests`. Priming budget **500** chars,
preserve budget **1000** chars.

## Files

- Create: `Sources/LocalFlowCore/Vocab/Vocabulary.swift`
- Test: `Tests/LocalFlowTests/VocabularyTests.swift`

## Interfaces

- Consumes: nothing.
- Produces:
  ```swift
  public struct VocabularyEntry: Codable, Equatable, Identifiable {
      public var id: UUID
      public var term: String
      public var variants: [String]
      public init(id: UUID = UUID(), term: String, variants: [String] = [])
  }

  public struct Vocabulary {
      public static let primingCharacterBudget = 500
      public static let preserveCharacterBudget = 1000
      public let entries: [VocabularyEntry]          // normalized
      public init(entries rawEntries: [VocabularyEntry])
      public var primingPrompt: String               // canonical terms, budgeted
      public var droppedFromPriming: Int             // terms that didn't fit priming
      public var preserveList: String                // canonical terms, budgeted
      public func applyReplacements(_ text: String) -> String
  }
  ```

## Steps

- [ ] **Step 1: Write the failing tests**

Create `Tests/LocalFlowTests/VocabularyTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./scripts/test.sh --filter VocabularyTests`
Expected: FAILS to build — `cannot find 'Vocabulary' in scope` / `cannot find 'VocabularyEntry' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/LocalFlowCore/Vocab/Vocabulary.swift`:

```swift
import Foundation

/// One vocabulary entry: a canonical term plus the ways Whisper mishears it.
/// An entry with no variants is priming-only. Stored raw (un-normalized) in
/// Settings; `Vocabulary` normalizes when deriving priming and replacement.
public struct VocabularyEntry: Codable, Equatable, Identifiable {
    public var id: UUID
    public var term: String
    public var variants: [String]

    public init(id: UUID = UUID(), term: String, variants: [String] = []) {
        self.id = id
        self.term = term
        self.variants = variants
    }
}

/// The normalized, derived form of a vocabulary list. Pure and testable.
/// Drives two mechanisms from one list:
///   - priming: canonical terms fed to Whisper as `initial_prompt`
///   - replacement: deterministic variant → canonical fixes after transcription
public struct Vocabulary {
    /// Conservative proxy for Whisper's ~224-token initial_prompt limit; sized
    /// to stay under it even for subword-heavy proper nouns.
    public static let primingCharacterBudget = 500
    /// Cap for the cleanup-protection term list injected into the Ollama prompt.
    public static let preserveCharacterBudget = 1000

    /// Normalized entries: trimmed; empty terms dropped; terms deduped
    /// (case-insensitive, first-wins); variants trimmed/deduped with any
    /// self-referential variant removed.
    public let entries: [VocabularyEntry]

    private let lookup: [String: String]        // lowercased variant → canonical term
    private let regex: NSRegularExpression?
    private let primingResult: (prompt: String, dropped: Int)

    public init(entries rawEntries: [VocabularyEntry]) {
        // 1. Normalize entries.
        var normalized: [VocabularyEntry] = []
        var seenTerms = Set<String>()
        for entry in rawEntries {
            let term = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else { continue }
            let termKey = term.lowercased()
            guard !seenTerms.contains(termKey) else { continue }
            seenTerms.insert(termKey)

            var variants: [String] = []
            var seenVariants = Set<String>()
            for variant in entry.variants {
                let v = variant.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !v.isEmpty else { continue }
                let vKey = v.lowercased()
                guard vKey != termKey else { continue }             // self-referential no-op
                guard !seenVariants.contains(vKey) else { continue }
                seenVariants.insert(vKey)
                variants.append(v)
            }
            normalized.append(VocabularyEntry(id: entry.id, term: term, variants: variants))
        }
        self.entries = normalized

        // 2. Build the variant → canonical lookup (first-wins across all entries).
        var lookup: [String: String] = [:]
        for entry in normalized {
            for variant in entry.variants where lookup[variant.lowercased()] == nil {
                lookup[variant.lowercased()] = entry.term
            }
        }
        self.lookup = lookup

        // 3. Compile one case-insensitive regex: alternation of all variants,
        //    escaped, longest-first, bounded so no match lands inside a word.
        if lookup.isEmpty {
            self.regex = nil
        } else {
            let alternatives = lookup.keys
                .sorted { $0.count > $1.count }
                .map { NSRegularExpression.escapedPattern(for: $0) }
            let pattern = "(?<!\\w)(" + alternatives.joined(separator: "|") + ")(?!\\w)"
            self.regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }

        // 4. Precompute the priming prompt within the character budget.
        self.primingResult = Vocabulary.budgetedJoin(
            normalized.map(\.term), budget: Vocabulary.primingCharacterBudget
        )
    }

    /// Canonical terms fed to Whisper as `initial_prompt`, within budget.
    public var primingPrompt: String { primingResult.prompt }

    /// How many terms did not fit the priming budget (still work as replacements).
    public var droppedFromPriming: Int { primingResult.dropped }

    /// Canonical terms for the cleanup-protection line, within budget. Empty
    /// when there are no terms.
    public var preserveList: String {
        Vocabulary.budgetedJoin(
            entries.map(\.term), budget: Vocabulary.preserveCharacterBudget
        ).prompt
    }

    /// Applies all variant → canonical replacements in a single left-to-right
    /// pass (no rule can re-match another rule's output). Identity when there
    /// are no variants.
    public func applyReplacements(_ text: String) -> String {
        guard let regex else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var lastEnd = 0
        for match in matches {
            let matched = ns.substring(with: match.range)
            let canonical = lookup[matched.lowercased()] ?? matched
            result += ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            result += canonical
            lastEnd = match.range.location + match.range.length
        }
        result += ns.substring(from: lastEnd)
        return result
    }

    /// Joins strings with ", " while the running length stays within `budget`;
    /// returns the joined string and how many were dropped (in list order).
    private static func budgetedJoin(_ items: [String], budget: Int) -> (prompt: String, dropped: Int) {
        var included: [String] = []
        var length = 0
        var dropped = 0
        for item in items {
            let addition = included.isEmpty ? item.count : item.count + 2  // ", "
            if length + addition <= budget {
                included.append(item)
                length += addition
            } else {
                dropped += 1
            }
        }
        return (included.joined(separator: ", "), dropped)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./scripts/test.sh --filter VocabularyTests`
Expected: PASS — all `VocabularyTests` green.

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalFlowCore/Vocab/Vocabulary.swift Tests/LocalFlowTests/VocabularyTests.swift
git commit -m "feat: add Vocabulary model (priming prompt + deterministic replacement)"
```
