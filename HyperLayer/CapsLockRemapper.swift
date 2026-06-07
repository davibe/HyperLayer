import Foundation

struct HIDUserKeyMapping: Codable, Equatable {
    let HIDKeyboardModifierMappingSrc: Int64
    let HIDKeyboardModifierMappingDst: Int64
}

final class CapsLockRemapper: ObservableObject {
    @Published private(set) var isInstalled = false
    @Published private(set) var lastError: String?

    private let capsLockUsage: Int64 = 0x700000039
    private let f18Usage: Int64 = 0x70000006D
    private var originalMappings: [HIDUserKeyMapping]?

    deinit {
        restore()
    }

    func install() {
        do {
            if originalMappings == nil {
                originalMappings = try readMappings()
            }

            let baseMappings = originalMappings ?? []
            var nextMappings = baseMappings.filter { $0.HIDKeyboardModifierMappingSrc != capsLockUsage }
            nextMappings.append(HIDUserKeyMapping(
                HIDKeyboardModifierMappingSrc: capsLockUsage,
                HIDKeyboardModifierMappingDst: f18Usage
            ))

            try writeMappings(nextMappings)
            isInstalled = true
            lastError = nil
        } catch {
            isInstalled = false
            lastError = error.localizedDescription
        }
    }

    func restore() {
        guard let originalMappings else {
            return
        }

        do {
            try writeMappings(originalMappings)
            self.originalMappings = nil
            isInstalled = false
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func readMappings() throws -> [HIDUserKeyMapping] {
        let output = try runHIDUtil(arguments: ["property", "--get", "UserKeyMapping"])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "(null)" {
            return []
        }

        if let data = trimmed.data(using: .utf8),
           let json = try? JSONDecoder().decode([String: [HIDUserKeyMapping]].self, from: data),
           let mappings = json["UserKeyMapping"] {
            return mappings
        }

        return parsePropertyListStyleMappings(trimmed)
    }

    private func writeMappings(_ mappings: [HIDUserKeyMapping]) throws {
        let payload = ["UserKeyMapping": mappings]
        let data = try JSONEncoder().encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw RemapperError.invalidJSON
        }
        _ = try runHIDUtil(arguments: ["property", "--set", json])
    }

    private func parsePropertyListStyleMappings(_ output: String) -> [HIDUserKeyMapping] {
        let blockPattern = #"\{[^}]*\}"#
        guard let blockRegex = try? NSRegularExpression(pattern: blockPattern) else {
            return []
        }

        let nsRange = NSRange(output.startIndex..<output.endIndex, in: output)
        return blockRegex.matches(in: output, range: nsRange).compactMap { match in
            guard let blockRange = Range(match.range, in: output) else {
                return nil
            }
            let block = String(output[blockRange])
            guard let src = value(for: "HIDKeyboardModifierMappingSrc", in: block),
                  let dst = value(for: "HIDKeyboardModifierMappingDst", in: block) else {
                return nil
            }
            return HIDUserKeyMapping(
                HIDKeyboardModifierMappingSrc: src,
                HIDKeyboardModifierMappingDst: dst
            )
        }
    }

    private func value(for key: String, in block: String) -> Int64? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "\(escapedKey)\\s*=\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsRange = NSRange(block.startIndex..<block.endIndex, in: block)
        guard let match = regex.firstMatch(in: block, range: nsRange),
              match.numberOfRanges == 2,
              let valueRange = Range(match.range(at: 1), in: block) else {
            return nil
        }
        return Int64(block[valueRange])
    }

    private func runHIDUtil(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw RemapperError.hidutilFailed(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
}

enum RemapperError: LocalizedError {
    case invalidJSON
    case hidutilFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Could not encode the hidutil mapping."
        case .hidutilFailed(let output):
            if output.isEmpty {
                return "hidutil failed without an error message."
            }
            return output
        }
    }
}
