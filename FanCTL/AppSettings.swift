import Foundation
internal import Combine

/// Configuración de control de un ventilador individual.
struct FanSettings: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    /// Temperatura máxima (°C) que se desea mantener en los sensores seleccionados.
    var maxTemperature: Double
    /// Temperatura mínima (°C) que se desea mantener en los sensores seleccionados.
    var minTemperature: Double
    /// Identificadores de los sensores que controlan este ventilador.
    var selectedSensorKeys: [String]

    init(id: Int, name: String, maxTemperature: Double = 90, minTemperature: Double = 30, selectedSensorKeys: [String] = []) {
        self.id = id
        self.name = name
        self.maxTemperature = maxTemperature
        self.minTemperature = minTemperature
        self.selectedSensorKeys = selectedSensorKeys
    }
}

/// Ajustes generales y por ventilador de la app.
struct AppSettings: Codable, Equatable {
    /// Intervalo de reescaneo del hardware en segundos.
    var refreshInterval: Double = 2.0
    /// Configuración por ventilador.
    var fans: [FanSettings] = []
}

/// Almacén persistente de configuración en `UserDefaults` (formato JSON).
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings = AppSettings()

    private let defaults: UserDefaults
    private static let defaultsKey = "appSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Devuelve la configuración de un ventilador, creando una por defecto si no existe.
    func fanSettings(for fan: FanInfo) -> FanSettings {
        if let existing = settings.fans.first(where: { $0.id == fan.id }) {
            return existing
        }
        return FanSettings(id: fan.id, name: fan.name)
    }

    /// Guarda la configuración de un ventilador (inserta o reemplaza).
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
