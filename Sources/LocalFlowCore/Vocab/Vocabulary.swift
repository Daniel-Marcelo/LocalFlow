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
