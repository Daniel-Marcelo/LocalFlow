# Task 2: Multilingual WhisperModel Cases

**Files:**
- Modify: `Sources/LocalFlowCore/STT/WhisperModel.swift`
- Modify: `Tests/LocalFlowTests/WhisperModelTests.swift`

**Interfaces:**
- Consumes: `DictationLanguage` (from Task 1)
- Produces:
  - New enum cases: `.base`, `.baseQ5`, `.small`, `.smallQ5`
  - `WhisperModel.supportedLanguages: Set<DictationLanguage>`
  - `WhisperModel.models(for: DictationLanguage) -> [WhisperModel]`
  - `WhisperModel.default(for: DictationLanguage) -> WhisperModel`

---

- [ ] **Step 1: Write the failing tests**

Add to `Tests/LocalFlowTests/WhisperModelTests.swift` (append new tests to the existing `@Suite`):

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh --filter WhisperModelTests`
Expected: compilation failure — new cases and methods don't exist.

- [ ] **Step 3: Update the existing `catalogContainsSpecModelsPlusQuantizedVariants` test**

The existing test asserts `allCases` ordering. Update it to include the new cases. Replace the body of `catalogContainsSpecModelsPlusQuantizedVariants`:

```swift
@Test func catalogContainsAllModels() {
    #expect(WhisperModel.allCases.map(\.rawValue) == [
        "base.en", "base.en-q5_1",
        "small.en", "small.en-q5_1",
        "large-v3-turbo", "large-v3-turbo-q5_0",
        "base", "base-q5_1",
        "small", "small-q5_1",
    ])
}
```

Also rename the test function from `catalogContainsSpecModelsPlusQuantizedVariants` to `catalogContainsAllModels`.

- [ ] **Step 4: Write the implementation**

Replace the full content of `Sources/LocalFlowCore/STT/WhisperModel.swift`:

```swift
import Foundation

public enum WhisperModel: String, CaseIterable, Identifiable {
    case baseEN = "base.en"
    case baseENQ5 = "base.en-q5_1"
    case smallEN = "small.en"
    case smallENQ5 = "small.en-q5_1"
    case largeV3Turbo = "large-v3-turbo"
    case largeV3TurboQ5 = "large-v3-turbo-q5_0"
    case base = "base"
    case baseQ5 = "base-q5_1"
    case small = "small"
    case smallQ5 = "small-q5_1"

    public static let `default` = WhisperModel.smallEN

    public var id: String { rawValue }

    public var fileName: String { "ggml-\(rawValue).bin" }

    public var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    public var displayName: String {
        switch self {
        case .baseEN: return "base.en — fastest"
        case .baseENQ5: return "base.en q5 — fastest, quantized"
        case .smallEN: return "small.en — balanced (default)"
        case .smallENQ5: return "small.en q5 — balanced, quantized"
        case .largeV3Turbo: return "large-v3-turbo — most accurate"
        case .largeV3TurboQ5: return "large-v3-turbo q5 — accurate, quantized"
        case .base: return "base — fastest"
        case .baseQ5: return "base q5 — fastest, quantized"
        case .small: return "small — balanced (default)"
        case .smallQ5: return "small q5 — balanced, quantized"
        }
    }

    public var approximateSize: String {
        switch self {
        case .baseEN: return "148 MB"
        case .baseENQ5: return "60 MB"
        case .smallEN: return "488 MB"
        case .smallENQ5: return "190 MB"
        case .largeV3Turbo: return "1.6 GB"
        case .largeV3TurboQ5: return "574 MB"
        case .base: return "148 MB"
        case .baseQ5: return "60 MB"
        case .small: return "488 MB"
        case .smallQ5: return "190 MB"
        }
    }

    public var supportedLanguages: Set<DictationLanguage> {
        switch self {
        case .baseEN, .baseENQ5, .smallEN, .smallENQ5:
            return [.english]
        case .base, .baseQ5, .small, .smallQ5:
            return [.portugueseBR]
        case .largeV3Turbo, .largeV3TurboQ5:
            return [.english, .portugueseBR]
        }
    }

    public static func models(for language: DictationLanguage) -> [WhisperModel] {
        allCases.filter { $0.supportedLanguages.contains(language) }
    }

    public static func `default`(for language: DictationLanguage) -> WhisperModel {
        switch language {
        case .english: return .smallEN
        case .portugueseBR: return .small
        }
    }

    public static var modelsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalFlow/models", isDirectory: true)
    }

    public var localURL: URL {
        Self.modelsDirectory.appendingPathComponent(fileName)
    }

    public var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh --filter WhisperModelTests`
Expected: all tests PASS.

- [ ] **Step 6: Verify the full build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 7: Commit**

```bash
git add Sources/LocalFlowCore/STT/WhisperModel.swift Tests/LocalFlowTests/WhisperModelTests.swift
git commit -m "feat: add multilingual Whisper models and language filtering"
```
