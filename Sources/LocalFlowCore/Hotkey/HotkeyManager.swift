import AppKit
import CoreGraphics
import os.log

/// Watches the global keyboard via a listen-only CGEventTap and turns the
/// configured activation key into activate/deactivate callbacks.
///
/// Bare modifiers (the Right Option default) only produce `flagsChanged`
/// events, so press vs. release is derived from whether the key's modifier
/// flag is set. Function keys produce ordinary keyDown/keyUp.
///
/// Requires Accessibility permission; `start()` returns false without it.
public final class HotkeyManager {
    private let log = Logger(subsystem: "com.localflow.app", category: "hotkey")

    /// Called on the main queue when dictation should start / stop.
    public var onActivate: (() -> Void)?
    public var onDeactivate: (() -> Void)?

    public var hotkey: HotkeyChoice = .default
    public var mode: ActivationMode = .hold

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyIsDown = false
    private var toggleActive = false

    public init() {}

    public var isRunning: Bool { tap != nil }

    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("CGEventTap creation failed — Accessibility permission missing?")
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("Event tap started for \(self.hotkey.rawValue, privacy: .public)")
        return true
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
        keyIsDown = false
        toggleActive = false
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS disables taps that stall or when the system deems it; re-enable.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
                log.warning("Event tap was disabled by the system; re-enabled")
            }
            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == hotkey.keyCode else { return }

        if hotkey.isModifierKey {
            guard type == .flagsChanged, let flag = hotkey.modifierFlag else { return }
            let pressed = event.flags.contains(flag)
            transition(pressed: pressed)
        } else {
            switch type {
            case .keyDown:
                // Ignore key-repeat while held.
                guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
                transition(pressed: true)
            case .keyUp:
                transition(pressed: false)
            default:
                break
            }
        }
    }

    private func transition(pressed: Bool) {
        guard pressed != keyIsDown else { return }
        keyIsDown = pressed

        switch mode {
        case .hold:
            fire(activate: pressed)
        case .toggle:
            guard pressed else { return }
            toggleActive.toggle()
            fire(activate: toggleActive)
        }
    }

    private func fire(activate: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            (activate ? self.onActivate : self.onDeactivate)?()
        }
    }
}
