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
}
