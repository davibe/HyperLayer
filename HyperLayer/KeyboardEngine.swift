import AppKit
import CoreGraphics
import Foundation

private let syntheticEventMarker: Int64 = 0x48594C52

private let keyboardTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let engine = Unmanaged<KeyboardEngine>.fromOpaque(refcon).takeUnretainedValue()
    return engine.handle(proxy: proxy, type: type, event: event)
}

final class KeyboardEngine: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcutsByTriggerKeyCode: [UInt16: Shortcut] = [:]
    private var passThroughUnmappedKeys = true
    private var layerIsDown = false
    private var suppressedLayerKeys = Set<UInt16>()

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
        passThroughUnmappedKeys = config.passThroughUnmappedKeys
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

        layerIsDown = false
        suppressedLayerKeys.removeAll()
        isRunning = true
        lastError = nil
        return true
    }

    func stop() {
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
        layerIsDown = false
        suppressedLayerKeys.removeAll()
        isRunning = false
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == KeyCodeCatalog.layerKeyCode {
            handleLayerKey(type: type)
            return nil
        }

        if keyCode == KeyCodeCatalog.capsLockKeyCode {
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

            if passThroughUnmappedKeys {
                return Unmanaged.passUnretained(event)
            }

            suppressedLayerKeys.insert(keyCode)
            return nil

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

    private func handleLayerKey(type: CGEventType) {
        switch type {
        case .keyDown:
            layerIsDown = true
        case .keyUp:
            layerIsDown = false
            suppressedLayerKeys.removeAll()
        default:
            break
        }
    }

    private func shortcut(for triggerKeyCode: UInt16) -> Shortcut? {
        shortcutsByTriggerKeyCode[triggerKeyCode]
    }

    private func post(_ shortcut: Shortcut) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        let keyCode = CGKeyCode(shortcut.keyCode)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        [keyDown, keyUp].forEach { event in
            event?.flags = shortcut.modifiers
            event?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        }

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
