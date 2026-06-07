import CoreGraphics
import Foundation

struct RecordedKeyStroke {
    let keyCode: UInt16
    let modifiers: CGEventFlags
}

private let recordingTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let recorder = Unmanaged<RecordingEventTap>.fromOpaque(refcon).takeUnretainedValue()
    return recorder.handle(proxy: proxy, type: type, event: event)
}

final class RecordingEventTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var suppressedKeyUpKeyCode: UInt16?
    private var isFinishing = false
    private var onRecord: ((RecordedKeyStroke) -> Void)?
    private var onCancel: (() -> Void)?

    deinit {
        stop()
    }

    @discardableResult
    func start(
        onRecord: @escaping (RecordedKeyStroke) -> Void,
        onCancel: @escaping () -> Void
    ) -> Bool {
        stop()
        self.onRecord = onRecord
        self.onCancel = onCancel

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: recordingTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            stop()
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            stop()
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
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
        suppressedKeyUpKeyCode = nil
        isFinishing = false
        onRecord = nil
        onCancel = nil
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .keyDown:
            guard !isFinishing else {
                return nil
            }

            isFinishing = true
            suppressedKeyUpKeyCode = keyCode

            if keyCode == 53 {
                DispatchQueue.main.async { [weak self] in
                    self?.onCancel?()
                }
            } else {
                let recordedKeyStroke = RecordedKeyStroke(
                    keyCode: keyCode,
                    modifiers: Self.relevantModifiers(from: event.flags)
                )
                DispatchQueue.main.async { [weak self] in
                    self?.onRecord?(recordedKeyStroke)
                }
            }

            return nil

        case .keyUp:
            if keyCode == suppressedKeyUpKeyCode {
                suppressedKeyUpKeyCode = nil
                return nil
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private static func relevantModifiers(from flags: CGEventFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.maskControl) {
            result.insert(.maskControl)
        }
        if flags.contains(.maskAlternate) {
            result.insert(.maskAlternate)
        }
        if flags.contains(.maskShift) {
            result.insert(.maskShift)
        }
        if flags.contains(.maskCommand) {
            result.insert(.maskCommand)
        }
        if flags.contains(.maskSecondaryFn) {
            result.insert(.maskSecondaryFn)
        }
        return result
    }
}
