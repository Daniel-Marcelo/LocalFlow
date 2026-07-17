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
