import AppKit
import CoreGraphics

// File-scope C callback required for CGEventTap
private let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<CaptureController>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = controller.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    guard keycode == 21, flags == [.maskCommand, .maskShift] else {
        return Unmanaged.passUnretained(event)
    }
    DispatchQueue.main.async { controller.beginCapture() }
    return nil
}

final class CaptureController: ObservableObject {
    @Published var lastCopied: Date? = nil
    @Published var isAccessibilityTrusted: Bool = false
    @Published var isScreenRecordingTrusted: Bool = false

    private var captureProcess: Process?
    fileprivate var eventTap: CFMachPort?
    private var tapRunLoopSource: CFRunLoopSource?
    private var accessibilityTimer: Timer?

    var hasAllPermissions: Bool { isAccessibilityTrusted && isScreenRecordingTrusted }

    init() {
        // Trigger Screen Recording prompt at launch rather than mid-capture
        let testImage = CGWindowListCreateImage(.zero, .optionOnScreenOnly, kCGNullWindowID, [])
        isScreenRecordingTrusted = testImage != nil

        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        isAccessibilityTrusted = trusted
        if trusted {
            installEventTap()
        } else {
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                let nowTrusted = AXIsProcessTrusted()
                DispatchQueue.main.async { self.isAccessibilityTrusted = nowTrusted }
                guard nowTrusted else { return }
                self.accessibilityTimer?.invalidate()
                self.accessibilityTimer = nil
                self.installEventTap()
            }
        }
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    private func installEventTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        tapRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func beginCapture() {
        guard captureProcess == nil else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-i", "-c"]
        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.captureProcess = nil
                if process.terminationStatus == 0 { self?.lastCopied = Date() }
            }
        }
        try? proc.run()
        captureProcess = proc
    }

    deinit {
        accessibilityTimer?.invalidate()
        if let source = tapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
    }
}
