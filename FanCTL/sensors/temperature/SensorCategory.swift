import Foundation

/// Categoría visual/funcional del sensor.
enum SensorCategory: String, Codable, CaseIterable {
    case socDie = "SoC Die (CPU/GPU Core)"
    case pmuBoard = "PMU / Placa Madre"
    case battery = "Batería / Alimentación"
    case smcGlobal = "SMC / Firmware Legacy"
    case unknown = "Otros Sensores"

    var iconName: String {
        switch self {
        case .socDie: return "cpu"
        case .pmuBoard: return "memorychip"
        case .battery: return "battery.100"
        case .smcGlobal: return "server.rack"
        case .unknown: return "thermometer.medium"
        }
    }
}
