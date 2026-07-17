# Task 6: Settings Editor UI

Self-contained. You need only this file and the repository. **Depends on Tasks 1
& 2** (`VocabularyEntry`, `Vocabulary`, `Settings.vocabulary`).

## Context

`SettingsView` (`Sources/LocalFlowCore/UI/SettingsView.swift`) is a SwiftUI
`Form` of `Section`s. This task adds a **Vocabulary** section with a row that
opens an editor **sheet**, keeping the main panel compact. The editor is a
`List` of rows (a `Term` field and a comma-separated `Also heard as` field),
with add/delete and a note when terms overflow the priming budget.

`Settings.vocabulary` is a computed `UserDefaults`-backed property (not a stored
`@Published` array), so the editor keeps a local `@State` working copy and writes
it back on change — the next dictation reads it fresh (no pipeline restart, no
reload wiring).

This is SwiftUI UI — there is **no unit test**. Verify with `swift build` and a
manual run.

**Global constraints:** Swift 6.1, language mode v5, `LocalFlowCore` module.
`Settings`, `Vocabulary`, and `VocabularyEntry` are in the same module, so
`VocabularyEditor` uses them directly. The two-parameter `onChange(of:)` used
below is macOS 14+ (the deployment target).

## Files

- Create: `Sources/LocalFlowCore/UI/VocabularyEditor.swift`
- Modify: `Sources/LocalFlowCore/UI/SettingsView.swift`

## Interfaces

- Consumes: `Settings.vocabulary`, `VocabularyEntry`, `Vocabulary`.
- Produces: `VocabularyEditor` (module-internal SwiftUI view).

## Steps

- [ ] **Step 1: Create the editor sheet**

Create `Sources/LocalFlowCore/UI/VocabularyEditor.swift`:

```swift
import SwiftUI

/// A sheet for editing the custom vocabulary list. Each row is a canonical term
/// plus its comma-separated "also heard as" variants. Edits are written back to
/// `Settings.vocabulary` live; the next dictation picks them up.
struct VocabularyEditor: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [VocabularyEntry] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Vocabulary").font(.headline)
                Spacer()
                Button("Add term") {
                    entries.append(VocabularyEntry(term: "", variants: []))
                }
            }
            .padding()

            if entries.isEmpty {
                Spacer()
                Text("No terms yet. Add proper nouns, jargon, or acronyms Whisper mishears.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach($entries) { $entry in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Term (e.g. Claude Code)", text: $entry.term)
                                .textFieldStyle(.roundedBorder)
                            TextField("Also heard as — comma separated (optional)",
                                      text: variantsBinding($entry))
                                .textFieldStyle(.roundedBorder)
                                .font(.callout)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { entries.remove(atOffsets: $0) }
                }
            }

            if droppedCount > 0 {
                Text("Some terms exceed Whisper's priming limit and won't bias recognition; their corrections still apply.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .bottom])
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 460, height: 420)
        .onAppear { entries = settings.vocabulary }
        .onChange(of: entries) { _, newValue in settings.vocabulary = newValue }
    }

    private var droppedCount: Int {
        Vocabulary(entries: entries).droppedFromPriming
    }

    /// Presents `variants` as a comma-separated string and parses edits back into
    /// a trimmed, non-empty `[String]`.
    private func variantsBinding(_ entry: Binding<VocabularyEntry>) -> Binding<String> {
        Binding(
            get: { entry.wrappedValue.variants.joined(separator: ", ") },
            set: { newValue in
                entry.wrappedValue.variants = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}
```

- [ ] **Step 2: Add the sheet-presentation state to `SettingsView`**

In `Sources/LocalFlowCore/UI/SettingsView.swift`, add a `@State` alongside the
existing ones near the top of the struct (after `@State private var ollamaStatus: String?`):

```swift
    @State private var showingVocabularyEditor = false
```

- [ ] **Step 3: Add the Vocabulary section**

Immediately after the `Section("Speech recognition") { … }` block (the one that
ends with `modelStatusRow`), insert:

```swift
            Section("Vocabulary") {
                Button {
                    showingVocabularyEditor = true
                } label: {
                    HStack {
                        Text("Custom terms")
                        Spacer()
                        Text("\(settings.vocabulary.count) term\(settings.vocabulary.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                Text("Terms you dictate that Whisper mishears — proper nouns, jargon, acronyms. Improves recognition and fixes consistent mistakes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
```

- [ ] **Step 4: Attach the sheet to the Form**

Find the `Form { … }`'s trailing modifiers (`.formStyle(.grouped)`,
`.frame(width: 480)`, `.frame(maxHeight: .infinity)`, `.onReceive(permissionTimer)`).
Add a `.sheet` modifier among them, e.g. directly after `.frame(maxHeight: .infinity)`:

```swift
        .sheet(isPresented: $showingVocabularyEditor) {
            VocabularyEditor(settings: settings)
        }
```

- [ ] **Step 5: Verify it compiles**

Run: `swift build`
Expected: build succeeds with no errors.

- [ ] **Step 6: Manual check**

```bash
make app
open LocalFlow.app
```

Open Settings → **Vocabulary** → **Custom terms** shows a count and a chevron.
Click it: the editor sheet opens. Add a term (`Claude Code`) with `Also heard as`
= `clod code, cloud code`, add a priming-only term (`Kubernetes`), delete a row,
click **Done**. Reopen — entries persist and the count updates. Then dictate a
sentence containing "clod code" and confirm it is injected as "Claude Code"
(this exercises Task 5's wiring end-to-end).

- [ ] **Step 7: Commit**

```bash
git add Sources/LocalFlowCore/UI/VocabularyEditor.swift Sources/LocalFlowCore/UI/SettingsView.swift
git commit -m "feat: add vocabulary editor to Settings"
```
