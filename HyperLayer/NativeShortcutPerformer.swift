import ApplicationServices
import AppKit
import CoreGraphics

final class NativeShortcutPerformer {
    func perform(shortcut: Shortcut) -> Bool {
        guard
            let menuShortcut = NativeMenuShortcut(shortcut: shortcut),
            let frontmostApplication = NSWorkspace.shared.frontmostApplication
        else {
            return false
        }

        let application = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
        guard
            let menuBar = elementAttribute(application, kAXMenuBarAttribute),
            let menuItem = matchingMenuItem(in: menuBar, shortcut: menuShortcut)
        else {
            return false
        }

        return AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success
    }

    private func matchingMenuItem(in element: AXUIElement, shortcut: NativeMenuShortcut) -> AXUIElement? {
        if menuItem(element, matches: shortcut) {
            return element
        }

        for child in elementArrayAttribute(element, kAXChildrenAttribute) {
            if let match = matchingMenuItem(in: child, shortcut: shortcut) {
                return match
            }
        }

        return nil
    }

    private func menuItem(_ element: AXUIElement, matches shortcut: NativeMenuShortcut) -> Bool {
        guard
            let virtualKey = intAttribute(element, kAXMenuItemCmdVirtualKeyAttribute),
            shortcut.virtualKeyCandidates.contains(UInt16(virtualKey)),
            let modifiers = intAttribute(element, kAXMenuItemCmdModifiersAttribute)
        else {
            return false
        }

        return modifiers == shortcut.axModifiers
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func elementArrayAttribute(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let value,
            CFGetTypeID(value) == CFArrayGetTypeID()
        else {
            return []
        }

        return value as? [AXUIElement] ?? []
    }

    private func intAttribute(_ element: AXUIElement, _ attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return (value as? NSNumber)?.intValue
    }
}

private struct NativeMenuShortcut {
    let virtualKeyCandidates: [UInt16]
    let axModifiers: Int

    private static let relevantModifiers: CGEventFlags = [
        .maskControl,
        .maskAlternate,
        .maskShift,
        .maskCommand,
        .maskSecondaryFn
    ]

    init?(shortcut: Shortcut) {
        guard shortcut.modifiers.intersection(Self.relevantModifiers) == [.maskControl, .maskSecondaryFn] else {
            return nil
        }

        switch shortcut.keyCode {
        case KeyCodeCatalog.leftArrowKeyCode:
            virtualKeyCandidates = [
                KeyCodeCatalog.leftArrowKeyCode,
                KeyCodeCatalog.homeKeyCode
            ]
        case KeyCodeCatalog.rightArrowKeyCode:
            virtualKeyCandidates = [
                KeyCodeCatalog.rightArrowKeyCode,
                KeyCodeCatalog.endKeyCode
            ]
        default:
            return nil
        }

        // AXMenuItemModifiers: Control (1 << 2) + NoCommand (1 << 3).
        axModifiers = 12
    }
}
