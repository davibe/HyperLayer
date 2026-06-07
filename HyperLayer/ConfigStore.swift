import Foundation

final class ConfigStore {
    private let defaults: UserDefaults
    private let key = "HyperLayerConfig"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HyperLayerConfig {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        do {
            return try JSONDecoder().decode(HyperLayerConfig.self, from: data)
        } catch {
            return .default
        }
    }

    func save(_ config: HyperLayerConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: key)
        } catch {
            assertionFailure("Could not encode HyperLayer config: \(error)")
        }
    }
}
