import Foundation
internal import Combine

/// Control configuration for a single fan.
struct FanSettings: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    /// Control mode selected by the user.
    var mode: FanMode
    /// Maximum temperature (°C) to maintain on the selected sensors.
    var maxTemperature: Double
    /// Minimum temperature (°C) to maintain on the selected sensors.
    var minTemperature: Double
    /// IDs of the sensors that control this fan.
    var selectedSensorKeys: [String]
    /// Fixed speed in RPM for manual mode manual.
    var manualRPM: Double
    /// Custom lower limit (RPM); `nil` = the fan's real range.
    var minRPM: Double?
    /// Custom upper limit (RPM); `nil` = the fan's real range.
    var maxRPM: Double?

    init(id: Int, name: String, mode: FanMode = .automatic, maxTemperature: Double = 90, minTemperature: Double = 30, selectedSensorKeys: [String] = [], manualRPM: Double = 1500, minRPM: Double? = nil, maxRPM: Double? = nil) {
        self.id = id
        self.name = name
        self.mode = mode
        self.maxTemperature = maxTemperature
        self.minTemperature = minTemperature
        self.selectedSensorKeys = selectedSensorKeys
        self.manualRPM = manualRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }

    enum CodingKeys: String, CodingKey {
        case id, name, mode, maxTemperature, minTemperature, selectedSensorKeys, manualRPM, minRPM, maxRPM
    }

    /// Preserves settings saved in previous versions (without limits).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        mode = try c.decode(FanMode.self, forKey: .mode)
        maxTemperature = try c.decodeIfPresent(Double.self, forKey: .maxTemperature) ?? 90
        minTemperature = try c.decodeIfPresent(Double.self, forKey: .minTemperature) ?? 30
        selectedSensorKeys = try c.decodeIfPresent([String].self, forKey: .selectedSensorKeys) ?? []
        manualRPM = try c.decodeIfPresent(Double.self, forKey: .manualRPM) ?? 1500
        minRPM = try c.decodeIfPresent(Double.self, forKey: .minRPM)
        maxRPM = try c.decodeIfPresent(Double.self, forKey: .maxRPM)
    }

    /// Effective lower limit (custom or the fan's real).
    func effectiveMinRPM(fanMinRPM: Double) -> Double { minRPM ?? fanMinRPM }

    /// Effective upper limit (custom or the fan's real).
    func effectiveMaxRPM(fanMaxRPM: Double) -> Double { maxRPM ?? fanMaxRPM }
}

/// General and per-fan settings of the app.
struct AppSettings: Codable, Equatable {
    /// Hardware rescan interval in seconds.
    var refreshInterval: Double = 2.0
    /// Sensor chosen for the max temperature indicator; `nil` = automatic (the hottest).
    var maxTempSensorKey: String? = nil
    /// Per-fan configuration.
    var fans: [FanSettings] = []

    enum CodingKeys: String, CodingKey {
        case refreshInterval, maxTempSensorKey, fans
    }

    init() {}

    /// Preserves settings saved in previous versions.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        refreshInterval = try c.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 2.0
        maxTempSensorKey = try c.decodeIfPresent(String.self, forKey: .maxTempSensorKey)
        fans = try c.decodeIfPresent([FanSettings].self, forKey: .fans) ?? []
    }
}

/// Persistent configuration store in `UserDefaults` (JSON format).
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings = AppSettings()

    private let defaults: UserDefaults
    private static let defaultsKey = "appSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Returns the configuration of a fan, creating a default one if it does not exist.
    func fanSettings(for fan: FanInfo) -> FanSettings {
        if let existing = settings.fans.first(where: { $0.id == fan.id }) {
            return existing
        }
        return FanSettings(id: fan.id, name: fan.name)
    }

    /// Saves the configuration of a fan (inserta o reemplaza).
    func updateFanSettings(_ fanSettings: FanSettings) {
        if let index = settings.fans.firstIndex(where: { $0.id == fanSettings.id }) {
            settings.fans[index] = fanSettings
        } else {
            settings.fans.append(fanSettings)
        }
        save()
    }

    func setRefreshInterval(_ interval: Double) {
        settings.refreshInterval = interval
        save()
    }

    func setMaxTempSensorKey(_ key: String?) {
        settings.maxTempSensorKey = key
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else { return }
        settings = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
