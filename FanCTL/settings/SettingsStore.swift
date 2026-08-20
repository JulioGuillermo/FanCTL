//
//  SettingsStore.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 20/08/2026.
//

internal import Combine

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

    func setMaxTempSensorKeys(_ keys: [String]) {
        settings.maxTempSensorKeys = keys
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
