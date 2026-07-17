import Testing
@testable import LocalFlowCore

@Suite struct TextInjectorTests {
    private func isHighSurrogate(_ unit: UInt16) -> Bool { (0xD800...0xDBFF).contains(unit) }
    private func isLowSurrogate(_ unit: UInt16) -> Bool { (0xDC00...0xDFFF).contains(unit) }

    @Test func chunksAsciiIntoSizedPieces() {
        let text = String(repeating: "a", count: 45)
        let chunks = TextInjector.utf16Chunks(text, size: 20)
        #expect(chunks.map(\.count) == [20, 20, 5])
        #expect(chunks.flatMap { $0 } == Array(text.utf16))
    }

    @Test func neverSplitsASurrogatePairAtTheBoundary() {
        // 19 ASCII + 👍 (U+1F44D → 0xD83D 0xDC4D). A naive size-20 split would
        // put the high surrogate at the end of chunk 1 and orphan the low one.
        let text = String(repeating: "a", count: 19) + "👍"
        let chunks = TextInjector.utf16Chunks(text, size: 20)

        for chunk in chunks {
            #expect(!(chunk.last.map(isHighSurrogate) ?? false))
            #expect(!(chunk.first.map(isLowSurrogate) ?? false))
        }
        // Round-trips losslessly.
        #expect(chunks.flatMap { $0 } == Array(text.utf16))
    }

    @Test func roundTripsMixedEmojiHeavyText() {
        let text = "Ship it 🚀 today, 👍 great work 🎉 everyone 🙌 done"
        let chunks = TextInjector.utf16Chunks(text, size: 8)
        for chunk in chunks {
            #expect(!(chunk.last.map(isHighSurrogate) ?? false))
        }
        #expect(chunks.flatMap { $0 } == Array(text.utf16))
    }

    @Test func emptyStringYieldsNoChunks() {
        #expect(TextInjector.utf16Chunks("", size: 20).isEmpty)
    }
}
