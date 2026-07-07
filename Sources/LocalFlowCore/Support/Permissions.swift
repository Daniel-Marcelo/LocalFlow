import AppKit
import ApplicationServices
import AVFoundation

/// The two TCC permissions everything hinges on: Accessibility (gates both
/// the event tap and CGEvent injection) and Microphone.
public enum Permissions {
    // MARK: Accessibility

    public static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system "wants to control this computer" prompt (once) and
    /// returns the current trust state.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    // MARK: Microphone

    public static var microphoneStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    public static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public static func openMicrophoneSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        )!
        NSWorkspace.shared.open(url)
    }
}
