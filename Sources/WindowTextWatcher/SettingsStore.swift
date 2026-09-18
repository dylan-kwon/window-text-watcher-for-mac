import Foundation

struct WatcherSettings: Codable, Equatable {
    var keywords: [String] = []
    var caseSensitive = false
    var ignoreWhitespace = false
    var cooldownSeconds: Double = DetectionGate.defaultCooldown
    var region = CGRect(x: 0, y: 0, width: 1, height: 1)

    private enum CodingKeys: String, CodingKey {
        case keywords
        case caseSensitive
        case ignoreWhitespace
        case cooldownSeconds
        case region
    }
}

extension WatcherSettings {
    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? keywords
        caseSensitive = try container.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? caseSensitive
        ignoreWhitespace = try container.decodeIfPresent(Bool.self, forKey: .ignoreWhitespace) ?? ignoreWhitespace
        cooldownSeconds = try container.decodeIfPresent(Double.self, forKey: .cooldownSeconds) ?? cooldownSeconds
        region = try container.decodeIfPresent(CGRect.self, forKey: .region) ?? region
    }
}

struct SettingsStore {
    static let storageKey = "watcherSettings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> WatcherSettings {
        guard let data = defaults.data(forKey: Self.storageKey),
              let settings = try? JSONDecoder().decode(WatcherSettings.self, from: data) else {
            return WatcherSettings()
        }

        return settings
    }

    func save(_ settings: WatcherSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(data, forKey: Self.storageKey)
    }
}
