# Task 1: DictationLanguage Enum

**Files:**
- Create: `Sources/LocalFlowCore/Support/DictationLanguage.swift`
- Test: `Tests/LocalFlowTests/DictationLanguageTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `DictationLanguage` enum (`english`, `portugueseBR`) — `String, CaseIterable, Identifiable`
  - `DictationLanguage.whisperCode: String` (returns `rawValue`: `"en"` / `"pt"`)
  - `DictationLanguage.displayName: String` (`"English"` / `"Português (Brasil)"`)
  - `DictationLanguage.default` → `.english`

---

- [ ] **Step 1: Write the failing test**

Create `Tests/LocalFlowTests/DictationLanguageTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh --filter DictationLanguageTests`
Expected: compilation failure — `DictationLanguage` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `Sources/LocalFlowCore/Support/DictationLanguage.swift`:

```swift
import Foundation

public enum DictationLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case portugueseBR = "pt"

    public var id: String { rawValue }

    public var whisperCode: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .portugueseBR: return "Português (Brasil)"
        }
    }

    public static let `default` = DictationLanguage.english
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh --filter DictationLanguageTests`
Expected: all 6 tests PASS.

- [ ] **Step 5: Verify the full build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!` — no existing code is broken.

- [ ] **Step 6: Commit**

```bash
git add Sources/LocalFlowCore/Support/DictationLanguage.swift Tests/LocalFlowTests/DictationLanguageTests.swift
git commit -m "feat: add DictationLanguage enum (English + PT-BR)"
```
