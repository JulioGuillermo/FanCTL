import Foundation
internal import Combine

/// Configuración de control de un ventilador individual.
struct FanSettings: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    /// Modo de control seleccionado por el usuario.
    var mode: FanMode
    /// Temperatura máxima (°C) que se desea mantener en los sensores seleccionados.
    var maxTemperature: Double
    /// Temperatura mínima (°C) que se desea mantener en los sensores seleccionados.
    var minTemperature: Double
    /// Identificadores de los sensores que controlan este ventilador.
    var selectedSensorKeys: [String]
    /// Velocidad fija en RPM para el modo manual.
    var manualRPM: Double
    /// Límite inferior personalizado (RPM); `nil` = rango real del ventilador.
    var minRPM: Double?
    /// Límite superior personalizado (RPM); `nil` = rango real del ventilador.
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

    /// Conserva los ajustes guardados en versiones anteriores (sin límites).
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

    /// Límite inferior efectivo (personalizado o real del ventilador).
    func effectiveMinRPM(fanMinRPM: Double) -> Double { minRPM ?? fanMinRPM }

    /// Límite superior efectivo (personalizado o real del ventilador).
    func effectiveMaxRPM(fanMaxRPM: Double) -> Double { maxRPM ?? fanMaxRPM }
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
