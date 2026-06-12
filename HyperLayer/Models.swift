import AppKit
import CoreGraphics
import Foundation

struct HyperLayerConfig: Codable, Equatable {
    var isEnabled: Bool
    var showsMenuBarIcon: Bool
    var showsDockIcon: Bool
    var mappings: [LayerMapping]

    static let `default` = HyperLayerConfig(
        isEnabled: true,
        showsMenuBarIcon: false,
        showsDockIcon: true,
        mappings: []
    )

    init(
        isEnabled: Bool,
        showsMenuBarIcon: Bool,
        showsDockIcon: Bool,
        mappings: [LayerMapping]
    ) {
        self.isEnabled = isEnabled
        self.showsMenuBarIcon = showsMenuBarIcon
        self.showsDockIcon = showsDockIcon
        self.mappings = mappings
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case showsMenuBarIcon
        case showsDockIcon
        case mappings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        showsMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showsMenuBarIcon) ?? false
        showsDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showsDockIcon) ?? true
        mappings = try container.decodeIfPresent([LayerMapping].self, forKey: .mappings) ?? []

        if !showsMenuBarIcon && !showsDockIcon {
            showsMenuBarIcon = true
        }
    }
}

struct LayerMapping: Codable, Identifiable, Equatable {
    var id: UUID
    var triggerKeyCode: UInt16?
    var output: Shortcut?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        triggerKeyCode: UInt16? = nil,
        output: Shortcut? = nil
    ) {
        self.id = id
        self.triggerKeyCode = triggerKeyCode
        self.output = output
        self.isEnabled = true
    }
}

struct Shortcut: Codable, Hashable, Equatable {
    var keyCode: UInt16
    var modifiersRawValue: UInt64

    init(keyCode: UInt16, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiers.rawValue
    }

    var modifiers: CGEventFlags {
        get { CGEventFlags(rawValue: modifiersRawValue) }
        set { modifiersRawValue = newValue.rawValue }
    }

    var displayName: String {
        var parts: [String] = []
        if modifiers.contains(.maskControl) {
            parts.append("Ctrl")
        }
        if modifiers.contains(.maskAlternate) {
            parts.append("Opt")
        }
        if modifiers.contains(.maskShift) {
            parts.append("Shift")
        }
        if modifiers.contains(.maskCommand) {
            parts.append("Cmd")
        }
        if modifiers.contains(.maskSecondaryFn) {
            parts.append("Fn")
        }
        parts.append(KeyCodeCatalog.name(for: keyCode))
        return parts.joined(separator: "+")
    }

    static func from(event: NSEvent) -> Shortcut {
        Shortcut(keyCode: event.keyCode, modifiers: CGEventFlags.from(event.modifierFlags))
    }

    static func output(from event: NSEvent) -> Shortcut {
        output(keyCode: event.keyCode, modifiers: CGEventFlags.from(event.modifierFlags))
    }

    static func output(keyCode: UInt16, modifiers: CGEventFlags) -> Shortcut {
        Shortcut(
            keyCode: normalizedOutputKeyCode(keyCode, modifiers: modifiers),
            modifiers: modifiers
        )
    }

    private static func normalizedOutputKeyCode(_ keyCode: UInt16, modifiers: CGEventFlags) -> UInt16 {
        guard modifiers.contains(.maskSecondaryFn) else {
            return keyCode
        }

        switch keyCode {
        case KeyCodeCatalog.homeKeyCode:
            return KeyCodeCatalog.leftArrowKeyCode
        case KeyCodeCatalog.endKeyCode:
            return KeyCodeCatalog.rightArrowKeyCode
        case KeyCodeCatalog.pageUpKeyCode:
            return KeyCodeCatalog.upArrowKeyCode
        case KeyCodeCatalog.pageDownKeyCode:
            return KeyCodeCatalog.downArrowKeyCode
        default:
            return keyCode
        }
    }
}

extension CGEventFlags {
    static func from(_ flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.control) {
            result.insert(.maskControl)
        }
        if flags.contains(.option) {
            result.insert(.maskAlternate)
        }
        if flags.contains(.shift) {
            result.insert(.maskShift)
        }
        if flags.contains(.command) {
            result.insert(.maskCommand)
        }
        if flags.contains(.function) {
            result.insert(.maskSecondaryFn)
        }
        return result
    }
}
