import AppKit
import CoreGraphics
import os.log

/// Puts the final text into whatever field has keyboard focus in the
/// frontmost app.
///
/// Primary method: set the pasteboard and synthesize ⌘V, then restore the
/// previous pasteboard contents — fast and reliable for long text. Fallback
/// method: synthesize the text as Unicode keyboard events for fields that
/// block paste. Both require Accessibility permission; both are blocked by
/// macOS secure-input (password) fields, which is a documented limitation.
public enum TextInjector {
    private static let log = Logger(subsystem: "com.localflow.app", category: "inject")

    /// How long the pasted text stays on the pasteboard before the previous
    /// contents come back. Long enough for any app to service the ⌘V.
    private static let clipboardRestoreDelay: TimeInterval = 0.6

    public static func inject(_ text: String, method: InjectionMethod) {
        guard !text.isEmpty else { return }
        switch method {
        case .paste: paste(text)
        case .type: type(text)
        }
    }

    // MARK: Paste

    private static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postKeystroke(virtualKey: CGKeyCode(9), flags: .maskCommand) // kVK_ANSI_V
        DispatchQueue.main.asyncAfter(deadline: .now() + clipboardRestoreDelay) {
            restore(saved, to: pasteboard)
        }
    }

    /// Captures every item and every type on the pasteboard so restore is
    /// lossless (files, images, rich text, …).
    static func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
    }

    static func restore(
        _ snapshot: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard
    ) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    // MARK: Type (fallback)

    /// Types the text as synthetic Unicode keyboard events, in small chunks —
    /// some apps drop characters from long single events.
    private static func type(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let chunkSize = 20
        var units = Array(text.utf16)
        while !units.isEmpty {
            var chunk = Array(units.prefix(chunkSize))
            units.removeFirst(chunk.count)
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                up.post(tap: .cghidEventTap)
            }
            usleep(8_000)
        }
    }

    // MARK: Keystroke synthesis

    private static func postKeystroke(virtualKey: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        else {
            log.error("Failed to create CGEvents for keystroke")
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
