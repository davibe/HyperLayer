import Carbon.HIToolbox
import Foundation

struct KeyInfo: Identifiable, Hashable {
    var id: UInt16 { keyCode }
    let keyCode: UInt16
    let name: String
}

enum KeyCodeCatalog {
    static let defaultTriggerKey: UInt16 = 0
    static let defaultOutputKey: UInt16 = 123
    static let capsLockKeyCode: UInt16 = 57
    static let layerKeyCode: UInt16 = 79
    static let homeKeyCode: UInt16 = 115
    static let pageUpKeyCode: UInt16 = 116
    static let endKeyCode: UInt16 = 119
    static let pageDownKeyCode: UInt16 = 121
    static let leftArrowKeyCode: UInt16 = 123
    static let rightArrowKeyCode: UInt16 = 124
    static let downArrowKeyCode: UInt16 = 125
    static let upArrowKeyCode: UInt16 = 126

    static let keys: [KeyInfo] = [
        KeyInfo(keyCode: 0, name: "A"),
        KeyInfo(keyCode: 1, name: "S"),
        KeyInfo(keyCode: 2, name: "D"),
        KeyInfo(keyCode: 3, name: "F"),
        KeyInfo(keyCode: 4, name: "H"),
        KeyInfo(keyCode: 5, name: "G"),
        KeyInfo(keyCode: 6, name: "Z"),
        KeyInfo(keyCode: 7, name: "X"),
        KeyInfo(keyCode: 8, name: "C"),
        KeyInfo(keyCode: 9, name: "V"),
        KeyInfo(keyCode: 11, name: "B"),
        KeyInfo(keyCode: 12, name: "Q"),
        KeyInfo(keyCode: 13, name: "W"),
        KeyInfo(keyCode: 14, name: "E"),
        KeyInfo(keyCode: 15, name: "R"),
        KeyInfo(keyCode: 16, name: "Y"),
        KeyInfo(keyCode: 17, name: "T"),
        KeyInfo(keyCode: 18, name: "1"),
        KeyInfo(keyCode: 19, name: "2"),
        KeyInfo(keyCode: 20, name: "3"),
        KeyInfo(keyCode: 21, name: "4"),
        KeyInfo(keyCode: 22, name: "6"),
        KeyInfo(keyCode: 23, name: "5"),
        KeyInfo(keyCode: 24, name: "="),
        KeyInfo(keyCode: 25, name: "9"),
        KeyInfo(keyCode: 26, name: "7"),
        KeyInfo(keyCode: 27, name: "-"),
        KeyInfo(keyCode: 28, name: "8"),
        KeyInfo(keyCode: 29, name: "0"),
        KeyInfo(keyCode: 30, name: "]"),
        KeyInfo(keyCode: 31, name: "O"),
        KeyInfo(keyCode: 32, name: "U"),
        KeyInfo(keyCode: 33, name: "["),
        KeyInfo(keyCode: 34, name: "I"),
        KeyInfo(keyCode: 35, name: "P"),
        KeyInfo(keyCode: 36, name: "Return"),
        KeyInfo(keyCode: 37, name: "L"),
        KeyInfo(keyCode: 38, name: "J"),
        KeyInfo(keyCode: 39, name: "'"),
        KeyInfo(keyCode: 40, name: "K"),
        KeyInfo(keyCode: 41, name: ";"),
        KeyInfo(keyCode: 42, name: "\\"),
        KeyInfo(keyCode: 43, name: ","),
        KeyInfo(keyCode: 44, name: "/"),
        KeyInfo(keyCode: 45, name: "N"),
        KeyInfo(keyCode: 46, name: "M"),
        KeyInfo(keyCode: 47, name: "."),
        KeyInfo(keyCode: 48, name: "Tab"),
        KeyInfo(keyCode: 49, name: "Space"),
        KeyInfo(keyCode: 50, name: "`"),
        KeyInfo(keyCode: 51, name: "Delete"),
        KeyInfo(keyCode: 53, name: "Escape"),
        KeyInfo(keyCode: 64, name: "F17"),
        KeyInfo(keyCode: 67, name: "Keypad *"),
        KeyInfo(keyCode: 69, name: "Keypad +"),
        KeyInfo(keyCode: 71, name: "Clear"),
        KeyInfo(keyCode: 75, name: "Keypad /"),
        KeyInfo(keyCode: 76, name: "Keypad Enter"),
        KeyInfo(keyCode: 78, name: "Keypad -"),
        KeyInfo(keyCode: 79, name: "F18"),
        KeyInfo(keyCode: 80, name: "F19"),
        KeyInfo(keyCode: 81, name: "Keypad ="),
        KeyInfo(keyCode: 82, name: "Keypad 0"),
        KeyInfo(keyCode: 83, name: "Keypad 1"),
        KeyInfo(keyCode: 84, name: "Keypad 2"),
        KeyInfo(keyCode: 85, name: "Keypad 3"),
        KeyInfo(keyCode: 86, name: "Keypad 4"),
        KeyInfo(keyCode: 87, name: "Keypad 5"),
        KeyInfo(keyCode: 88, name: "Keypad 6"),
        KeyInfo(keyCode: 89, name: "Keypad 7"),
        KeyInfo(keyCode: 90, name: "F20"),
        KeyInfo(keyCode: 91, name: "Keypad 8"),
        KeyInfo(keyCode: 92, name: "Keypad 9"),
        KeyInfo(keyCode: 96, name: "F5"),
        KeyInfo(keyCode: 97, name: "F6"),
        KeyInfo(keyCode: 98, name: "F7"),
        KeyInfo(keyCode: 99, name: "F3"),
        KeyInfo(keyCode: 100, name: "F8"),
        KeyInfo(keyCode: 101, name: "F9"),
        KeyInfo(keyCode: 103, name: "F11"),
        KeyInfo(keyCode: 105, name: "F13"),
        KeyInfo(keyCode: 106, name: "F16"),
        KeyInfo(keyCode: 107, name: "F14"),
        KeyInfo(keyCode: 109, name: "F10"),
        KeyInfo(keyCode: 111, name: "F12"),
        KeyInfo(keyCode: 113, name: "F15"),
        KeyInfo(keyCode: 114, name: "Help"),
        KeyInfo(keyCode: 115, name: "Home"),
        KeyInfo(keyCode: 116, name: "Page Up"),
        KeyInfo(keyCode: 117, name: "Forward Delete"),
        KeyInfo(keyCode: 118, name: "F4"),
        KeyInfo(keyCode: 119, name: "End"),
        KeyInfo(keyCode: 120, name: "F2"),
        KeyInfo(keyCode: 121, name: "Page Down"),
        KeyInfo(keyCode: 122, name: "F1"),
        KeyInfo(keyCode: 123, name: "Left Arrow"),
        KeyInfo(keyCode: 124, name: "Right Arrow"),
        KeyInfo(keyCode: 125, name: "Down Arrow"),
        KeyInfo(keyCode: 126, name: "Up Arrow")
    ]

    private static let namesByKeyCode = Dictionary(uniqueKeysWithValues: keys.map { ($0.keyCode, $0.name) })
    private static let fixedNamesByKeyCode: [UInt16: String] = [
        36: "Return",
        48: "Tab",
        49: "Space",
        51: "Delete",
        53: "Escape",
        64: "F17",
        67: "Keypad *",
        69: "Keypad +",
        71: "Clear",
        75: "Keypad /",
        76: "Keypad Enter",
        78: "Keypad -",
        79: "F18",
        80: "F19",
        81: "Keypad =",
        82: "Keypad 0",
        83: "Keypad 1",
        84: "Keypad 2",
        85: "Keypad 3",
        86: "Keypad 4",
        87: "Keypad 5",
        88: "Keypad 6",
        89: "Keypad 7",
        90: "F20",
        91: "Keypad 8",
        92: "Keypad 9",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "Forward Delete",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "Left Arrow",
        124: "Right Arrow",
        125: "Down Arrow",
        126: "Up Arrow"
    ]

    static func name(for keyCode: UInt16) -> String {
        if let fixedName = fixedNamesByKeyCode[keyCode] {
            return fixedName
        }

        if let layoutName = currentKeyboardLayoutName(for: keyCode) {
            return layoutName
        }

        return namesByKeyCode[keyCode] ?? "Key \(keyCode)"
    }

    static func sortedKeys() -> [KeyInfo] {
        keys
    }

    private static func currentKeyboardLayoutName(for keyCode: UInt16) -> String? {
        guard
            let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutDataPointer = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        guard let layoutBytes = CFDataGetBytePtr(layoutData) else {
            return nil
        }

        return layoutBytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { keyboardLayout in
            let keyboardType = UInt32(LMGetKbdType())
            var deadKeyState: UInt32 = 0
            var actualLength = 0
            var chars = [UniChar](repeating: 0, count: 4)

            let status = UCKeyTranslate(
                keyboardLayout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                keyboardType,
                UInt32(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                chars.count,
                &actualLength,
                &chars
            )

            guard status == noErr, actualLength > 0 else {
                return nil
            }

            let translated = String(utf16CodeUnits: chars, count: actualLength)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !translated.isEmpty else {
                return nil
            }

            return displayName(forTranslatedKey: translated)
        }
    }

    private static func displayName(forTranslatedKey translated: String) -> String {
        if translated.range(of: #"^[a-z]$"#, options: .regularExpression) != nil {
            return translated.uppercased()
        }

        return translated
    }
}
