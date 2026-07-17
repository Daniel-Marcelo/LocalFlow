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

    /// Device-dependent modifier bit (IOKit `NX_DEVICE*KEYMASK`) identifying the
    /// *specific* physical key. Unlike `modifierFlag`, this distinguishes Left
    /// from Right Option, so a flagsChanged event can be read as press vs.
    /// release even while the sibling key is held.
    public var deviceModifierMask: UInt64? {
        switch self {
        case .leftOption: return 0x0000_0020    // NX_DEVICELALTKEYMASK
        case .rightOption: return 0x0000_0040   // NX_DEVICERALTKEYMASK
        case .rightCommand: return 0x0000_0010  // NX_DEVICERCMDKEYMASK
        case .rightControl: return 0x0000_2000  // NX_DEVICERCTLKEYMASK
        case .f13, .f14, .f15: return nil
        }
    }

    /// Given the raw `CGEventFlags` of a `flagsChanged` event for this key's
    /// keycode, is the key now down? Reads the device-specific bit so releasing
    /// one Option key while the other is held still registers as a release.
    /// Falls back to the generic mask if no device bit is known.
    public func isPressed(rawFlags: UInt64) -> Bool {
        if let mask = deviceModifierMask { return rawFlags & mask != 0 }
        if let flag = modifierFlag { return rawFlags & flag.rawValue != 0 }
        return false
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
