import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import IOKit.hid
import OSLog

private let syntheticEventMarker: Int64 = 0x48594C52

private struct SyntheticModifierKey {
    let flag: CGEventFlags
    let keyCode: CGKeyCode
}

private let keyboardTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let engine = Unmanaged<KeyboardEngine>.fromOpaque(refcon).takeUnretainedValue()
    return engine.handle(proxy: proxy, type: type, event: event)
}

private let physicalCapsLockCallback: IOHIDValueCallback = { context, result, _, value in
    guard result == kIOReturnSuccess, let context else {
        return
    }

    let element = IOHIDValueGetElement(value)
    guard IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad,
          IOHIDElementGetUsage(element) == kHIDUsage_KeyboardCapsLock else {
        return
    }

    let monitor = Unmanaged<PhysicalCapsLockMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.received(isDown: IOHIDValueGetIntegerValue(value) != 0)
}

private final class PhysicalCapsLockMonitor {
    private let manager: IOHIDManager
    private let onStateChange: (Bool) -> Void
    private let logger = Logger(subsystem: "com.dade.HyperLayer", category: "physical-keyboard")
    private(set) var isRunning = false

    init(onStateChange: @escaping (Bool) -> Void) {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.onStateChange = onStateChange
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else {
            return true
        }

        let deviceMatching: [String: Int] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ]
        let inputMatching: [String: Int] = [
            kIOHIDElementUsagePageKey: kHIDPage_KeyboardOrKeypad,
            kIOHIDElementUsageKey: kHIDUsage_KeyboardCapsLock
        ]

        IOHIDManagerSetDeviceMatching(manager, deviceMatching as CFDictionary)
        IOHIDManagerSetInputValueMatching(manager, inputMatching as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(
            manager,
            physicalCapsLockCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            logger.error("Could not open physical keyboard monitor: \(result)")
            return false
        }

        isRunning = true
        logger.info("Physical Caps Lock monitor started")
        return true
    }

    func stop() {
        guard isRunning else {
            return
        }

        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        isRunning = false
    }

    fileprivate func received(isDown: Bool) {
        logger.debug("Physical Caps Lock state: \(isDown)")
        onStateChange(isDown)
    }
}

final class KeyboardEngine: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let logger = Logger(subsystem: "com.dade.HyperLayer", category: "keyboard")
    private lazy var physicalCapsLockMonitor = PhysicalCapsLockMonitor { [weak self] isDown in
        self?.handlePhysicalLayerState(isDown: isDown)
    }
    private var shortcutsByTriggerKeyCode: [UInt16: Shortcut] = [:]
    private var layerIsDown = false
    private var layerFlagsChangedIsDown = false
    private var physicalLayerState: Bool?
    private var suppressedLayerKeys = Set<UInt16>()
    private let syntheticModifierKeys = [
        SyntheticModifierKey(flag: .maskControl, keyCode: CGKeyCode(kVK_Control)),
        SyntheticModifierKey(flag: .maskAlternate, keyCode: CGKeyCode(kVK_Option)),
        SyntheticModifierKey(flag: .maskShift, keyCode: CGKeyCode(kVK_Shift)),
        SyntheticModifierKey(flag: .maskCommand, keyCode: CGKeyCode(kVK_Command)),
        SyntheticModifierKey(flag: .maskSecondaryFn, keyCode: CGKeyCode(kVK_Function))
    ]

    deinit {
        stop()
    }

    func update(config: HyperLayerConfig) {
        var nextShortcuts: [UInt16: Shortcut] = [:]
        for mapping in config.mappings where mapping.isEnabled {
            guard let triggerKeyCode = mapping.triggerKeyCode,
                  let output = mapping.output else {
                continue
            }
            nextShortcuts[triggerKeyCode] = output
        }

        if nextShortcuts != shortcutsByTriggerKeyCode {
            suppressedLayerKeys.removeAll()
        }

        shortcutsByTriggerKeyCode = nextShortcuts
    }

    @discardableResult
    func start() -> Bool {
        if isRunning {
            return true
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "Could not create the keyboard event tap. Check Accessibility and Input Monitoring permissions."
            isRunning = false
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            lastError = "Could not attach the keyboard event tap to the run loop."
            isRunning = false
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        _ = physicalCapsLockMonitor.start()

        resetLayerState()
        isRunning = true
        lastError = nil
        return true
    }

    func stop() {
        physicalCapsLockMonitor.stop()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
        physicalLayerState = nil
        resetLayerState()
        isRunning = false
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logger.notice("Keyboard event tap was disabled by macOS; re-enabling it")
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == KeyCodeCatalog.layerKeyCode || keyCode == KeyCodeCatalog.capsLockKeyCode {
            handleLayerKey(type: type, event: event)
            return nil
        }

        guard layerIsDown else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            if let shortcut = shortcut(for: keyCode) {
                suppressedLayerKeys.insert(keyCode)
                post(shortcut)
                return nil
            }

            return Unmanaged.passUnretained(event)

        case .keyUp:
            if suppressedLayerKeys.contains(keyCode) {
                suppressedLayerKeys.remove(keyCode)
                return nil
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleLayerKey(type: CGEventType, event: CGEvent) {
        if let physicalLayerState {
            if physicalLayerState {
                layerIsDown = true
            } else {
                resetLayerState()
            }
            return
        }

        switch type {
        case .keyDown:
            layerIsDown = true
        case .keyUp:
            resetLayerState()
        case .flagsChanged:
            // Some Caps Lock remap paths surface as flagsChanged instead of keyDown/keyUp.
            layerFlagsChangedIsDown.toggle()
            if layerFlagsChangedIsDown {
                layerIsDown = true
            } else {
                resetLayerState()
            }
        default:
            break
        }
    }

    private func handlePhysicalLayerState(isDown: Bool) {
        physicalLayerState = isDown
        if isDown {
            layerIsDown = true
        } else {
            resetLayerState()
        }
    }

    private func resetLayerState() {
        layerIsDown = false
        layerFlagsChangedIsDown = false
        suppressedLayerKeys.removeAll()
    }

    private func shortcut(for triggerKeyCode: UInt16) -> Shortcut? {
        shortcutsByTriggerKeyCode[triggerKeyCode]
    }

    private func post(_ shortcut: Shortcut) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        if shortcut.modifiers.contains(.maskSecondaryFn) {
            postWithModifierTransitions(shortcut, source: source)
            return
        }

        postKeyStroke(keyCode: CGKeyCode(shortcut.keyCode), flags: shortcut.modifiers, source: source)
    }

    private func postWithModifierTransitions(_ shortcut: Shortcut, source: CGEventSource) {
        let modifierKeys = syntheticModifierKeys.filter { shortcut.modifiers.contains($0.flag) }
        var activeFlags: CGEventFlags = []

        for modifierKey in modifierKeys {
            activeFlags.insert(modifierKey.flag)
            postModifier(keyCode: modifierKey.keyCode, keyDown: true, flags: activeFlags, source: source)
        }

        postKeyStroke(keyCode: CGKeyCode(shortcut.keyCode), flags: shortcut.modifiers, source: source)

        for modifierKey in modifierKeys.reversed() {
            activeFlags.remove(modifierKey.flag)
            postModifier(keyCode: modifierKey.keyCode, keyDown: false, flags: activeFlags, source: source)
        }
    }

    private func postKeyStroke(keyCode: CGKeyCode, flags: CGEventFlags, source: CGEventSource) {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        [keyDown, keyUp].forEach { event in
            mark(event, flags: flags)
        }

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func postModifier(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags, source: CGEventSource) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
        mark(event, flags: flags)
        event?.post(tap: .cghidEventTap)
    }

    private func mark(_ event: CGEvent?, flags: CGEventFlags) {
        event?.flags = flags
        event?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
    }
}
