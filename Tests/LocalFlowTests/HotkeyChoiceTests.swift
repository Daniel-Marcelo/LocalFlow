import CoreGraphics
import Testing
@testable import LocalFlowCore

@Suite struct HotkeyChoiceTests {
    @Test func rightOptionIsTheDefaultAndArrivesViaFlagsChanged() {
        #expect(HotkeyChoice.default == .rightOption)
        #expect(HotkeyChoice.rightOption.keyCode == 0x3D)
        #expect(HotkeyChoice.rightOption.isModifierKey)
    }

    @Test func modifierKeyCodes() {
        #expect(HotkeyChoice.leftOption.keyCode == 0x3A)
        #expect(HotkeyChoice.rightCommand.keyCode == 0x36)
        #expect(HotkeyChoice.rightControl.keyCode == 0x3E)
        #expect(HotkeyChoice.leftOption.isModifierKey)
        #expect(HotkeyChoice.rightCommand.isModifierKey)
        #expect(HotkeyChoice.rightControl.isModifierKey)
    }

    @Test func functionKeysAreNotModifiers() {
        #expect(HotkeyChoice.f13.keyCode == 0x69)
        #expect(HotkeyChoice.f14.keyCode == 0x6B)
        #expect(HotkeyChoice.f15.keyCode == 0x71)
        #expect(!HotkeyChoice.f13.isModifierKey)
        #expect(!HotkeyChoice.f14.isModifierKey)
        #expect(!HotkeyChoice.f15.isModifierKey)
    }

    @Test func modifierFlagMasks() {
        #expect(HotkeyChoice.rightOption.modifierFlag == .maskAlternate)
        #expect(HotkeyChoice.leftOption.modifierFlag == .maskAlternate)
        #expect(HotkeyChoice.rightCommand.modifierFlag == .maskCommand)
        #expect(HotkeyChoice.rightControl.modifierFlag == .maskControl)
        #expect(HotkeyChoice.f13.modifierFlag == nil)
    }

    @Test func everyChoiceHasADisplayName() {
        for choice in HotkeyChoice.allCases {
            #expect(!choice.displayName.isEmpty)
        }
    }

    // MARK: Press/release from device-dependent flags
    //
    // The generic .maskAlternate bit can't tell Left Option from Right Option,
    // so releasing one while the other is held used to look like "still down".
    // isPressed(rawFlags:) reads the device-specific bit for the exact key.

    /// Device-dependent CGEventFlags bits (IOKit NX_DEVICE*KEYMASK).
    private static let leftOptionBit: UInt64 = 0x0000_0020
    private static let rightOptionBit: UInt64 = 0x0000_0040
    private static let genericOptionBit = CGEventFlags.maskAlternate.rawValue

    @Test func rightOptionPressedFromItsOwnDeviceBit() {
        let flags = Self.genericOptionBit | Self.rightOptionBit
        #expect(HotkeyChoice.rightOption.isPressed(rawFlags: flags))
    }

    @Test func rightOptionNotPressedWhenOnlyLeftOptionHeld() {
        // The bug: Left Option held sets the generic Alternate bit, but Right
        // Option's device bit is clear, so Right Option must read as released.
        let flags = Self.genericOptionBit | Self.leftOptionBit
        #expect(!HotkeyChoice.rightOption.isPressed(rawFlags: flags))
    }

    @Test func leftOptionNotPressedWhenOnlyRightOptionHeld() {
        let flags = Self.genericOptionBit | Self.rightOptionBit
        #expect(!HotkeyChoice.leftOption.isPressed(rawFlags: flags))
    }

    @Test func modifierNotPressedWhenNoFlagsSet() {
        #expect(!HotkeyChoice.rightOption.isPressed(rawFlags: 0))
        #expect(!HotkeyChoice.rightCommand.isPressed(rawFlags: 0))
        #expect(!HotkeyChoice.rightControl.isPressed(rawFlags: 0))
    }

    @Test func rightCommandAndControlUseTheirDeviceBits() {
        #expect(HotkeyChoice.rightCommand.isPressed(rawFlags: 0x0000_0010))
        #expect(HotkeyChoice.rightControl.isPressed(rawFlags: 0x0000_2000))
        // A different modifier's bit must not register as this key.
        #expect(!HotkeyChoice.rightCommand.isPressed(rawFlags: 0x0000_2000))
    }
}
