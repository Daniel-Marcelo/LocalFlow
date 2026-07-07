import CoreGraphics

/// The activation keys the user can pick. Bare modifiers arrive as
/// `flagsChanged` CGEvents (press = flag set, release = flag cleared, with the
/// key identified by its keycode); function keys arrive as ordinary
/// keyDown/keyUp events.
public enum HotkeyChoice: String, CaseIterable, Identifiable {
    case rightOption, leftOption, rightCommand, rightControl, f13, f14, f15

    public static let `default` = HotkeyChoice.rightOption

    public var id: String { rawValue }

    public var keyCode: Int64 {
        switch self {
        case .rightOption: return 0x3D
        case .leftOption: return 0x3A
        case .rightCommand: return 0x36
        case .rightControl: return 0x3E
        case .f13: return 0x69
        case .f14: return 0x6B
        case .f15: return 0x71
        }
    }

    public var isModifierKey: Bool {
        switch self {
        case .rightOption, .leftOption, .rightCommand, .rightControl: return true
        case .f13, .f14, .f15: return false
        }
    }

    /// The CGEventFlags bit that tracks this modifier in flagsChanged events.
    public var modifierFlag: CGEventFlags? {
        switch self {
        case .rightOption, .leftOption: return .maskAlternate
        case .rightCommand: return .maskCommand
        case .rightControl: return .maskControl
        case .f13, .f14, .f15: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .rightOption: return "Right Option ⌥"
        case .leftOption: return "Left Option ⌥"
        case .rightCommand: return "Right Command ⌘"
        case .rightControl: return "Right Control ⌃"
        case .f13: return "F13"
        case .f14: return "F14"
        case .f15: return "F15"
        }
    }
}
