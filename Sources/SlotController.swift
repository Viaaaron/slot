import AppKit
import ApplicationServices
import Foundation

private let slotEventMarker: Int64 = 0x534C4F54

final class SlotController {
    private let ring = ClipboardRing()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollingTimer: Timer?
    private var restoreWorkItem: DispatchWorkItem?
    private var externalCaptureWorkItems: [DispatchWorkItem] = []

    private(set) var cycleIndex: Int?
    private var cycleApplicationPID: pid_t?
    private var statusHandler: (() -> Void)?

    init(statusHandler: @escaping () -> Void) {
        self.statusHandler = statusHandler
        ring.onChange = { [weak self] in
            guard let self else { return }
            Diagnostics.log("Clipboard ring updated; count=\(self.ring.entries.count)")
            self.statusHandler?()
        }
    }

    var entries: [ClipboardEntry] { ring.entries }
    var isTrusted: Bool { AXIsProcessTrusted() }
    var isListening: Bool { eventTap != nil }

    func start() {
        Diagnostics.log("Starting controller; trusted=\(AXIsProcessTrusted())")
        requestAccessibilityIfNeeded()
        startClipboardPolling()
        installEventTap()
    }

    func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else {
            if eventTap == nil { installEventTap() }
            return
        }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func clearSlots() {
        endCycle()
        ring.clear()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return false
        }

        if event.getIntegerValueField(.eventSourceUserData) == slotEventMarker {
            return false
        }

        if type == .flagsChanged {
            if !event.flags.contains(.maskCommand) {
                endCycle()
            }
            return false
        }

        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            endCycle()
            return false
        }

        guard type == .keyDown else { return false }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let relevantModifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        let isPlainCommandV = keyCode == 9 && relevantModifiers == .maskCommand

        if isPlainCommandV {
            if isWisprFlowPasteEvent(event) {
                passThroughWisprFlowPaste()
                return false
            }

            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat { cyclePaste() }
            return true
        }

        if cycleIndex != nil {
            endCycle()
        }
        return false
    }

    private func cyclePaste() {
        restoreWorkItem?.cancel()
        let capturedExternalClipboard = ring.captureCurrentIfChanged()
        if capturedExternalClipboard {
            cycleIndex = nil
            cycleApplicationPID = nil
        }
        guard !ring.entries.isEmpty else { return }

        let currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let canReplacePrevious = cycleIndex != nil
            && currentPID == cycleApplicationPID

        let nextIndex: Int
        if canReplacePrevious, let existingIndex = cycleIndex {
            postCommandKey(keyCode: 6) // Z
            nextIndex = (existingIndex + 1) % ring.entries.count
        } else {
            nextIndex = 0
            cycleApplicationPID = currentPID
        }

        guard ring.writeEntry(at: nextIndex) else { return }
        cycleIndex = nextIndex
        Diagnostics.log("Command-V handled; slot=\(nextIndex + 1)/\(ring.entries.count), replacedPrevious=\(canReplacePrevious)")
        postCommandKey(keyCode: 9) // V
        statusHandler?()
    }

    private func passThroughWisprFlowPaste() {
        restoreWorkItem?.cancel()
        restoreWorkItem = nil
        endCycle(restoreTopSlot: false)
        captureExternalClipboardSoon(reason: "Wispr Flow paste")
        Diagnostics.log("Passing through Wispr Flow Command-V event")
    }

    private func captureExternalClipboardSoon(reason: String) {
        externalCaptureWorkItems.forEach { $0.cancel() }
        externalCaptureWorkItems.removeAll()

        let delays: [TimeInterval] = [0.0, 0.03, 0.12, 0.35]
        for delay in delays {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.ring.captureCurrentIfChanged() {
                    Diagnostics.log("Captured clipboard after \(reason)")
                }
            }
            externalCaptureWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func isWisprFlowPasteEvent(_ event: CGEvent) -> Bool {
        let sourcePID = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
        guard sourcePID > 0, sourcePID != getpid(),
              let sourceApplication = NSRunningApplication(processIdentifier: sourcePID) else {
            return false
        }

        let searchableIdentifiers = [
            sourceApplication.localizedName,
            sourceApplication.bundleIdentifier,
            sourceApplication.executableURL?.lastPathComponent
        ]
        return searchableIdentifiers.contains { value in
            value?.range(of: "wispr", options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func endCycle(restoreTopSlot: Bool = true) {
        guard cycleIndex != nil else { return }
        cycleIndex = nil
        cycleApplicationPID = nil
        Diagnostics.log("Paste cycle ended")
        statusHandler?()

        restoreWorkItem?.cancel()
        restoreWorkItem = nil
        guard restoreTopSlot else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            _ = self.ring.writeEntry(at: 0)
        }
        restoreWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func postCommandKey(keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        for event in [down, up] {
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: slotEventMarker)
            event.post(tap: .cghidEventTap)
        }
    }

    private func startClipboardPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            _ = self?.ring.captureCurrentIfChanged()
        }
    }

    private func installEventTap() {
        guard eventTap == nil, AXIsProcessTrusted() else { return }

        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<SlotController>.fromOpaque(userInfo).takeUnretainedValue()
            return controller.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Diagnostics.log("Failed to install Command-V event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        Diagnostics.log("Command-V event tap installed")
        statusHandler?()
    }
}
