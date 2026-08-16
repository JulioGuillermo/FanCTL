import Foundation

/// Categoría visual/funcional del sensor.
enum SensorCategory: String, Codable, CaseIterable {
    case socDie = "SoC Die (CPU/GPU Core)"
    case pmuBoard = "PMU / Placa Madre"
    case powerManagement = "Gestión de energía"
    case storage = "Almacenamiento (SSD)"
    case battery = "Batería / Alimentación"
    case smcGlobal = "SMC / Firmware Legacy"
    case unknown = "Otros Sensores"

    var iconName: String {
        switch self {
        case .socDie: return "cpu"
        case .pmuBoard: return "simcard.fill"
        case .powerManagement: return "bolt.fill"
        case .storage: return "internaldrive"
        case .battery: return "battery.100"
        case .smcGlobal: return "server.rack"
        case .unknown: return "thermometer.medium"
        }
    }
}
