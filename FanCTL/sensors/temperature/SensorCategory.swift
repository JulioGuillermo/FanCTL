import Foundation

/// Visual/functional category of the sensor.
enum SensorCategory: String, Codable, CaseIterable {
    case socDie = "SoC Die (CPU/GPU Core)"
    case pmuBoard = "PMU / Motherboard"
    case powerManagement = "Power management"
    case storage = "Storage (SSD)"
    case battery = "Battery / Power"
    case smcGlobal = "SMC / Legacy firmware"
    case unknown = "Other sensors"

    var iconName: String {
        switch self {
        case .socDie: return "cpu"
        case .pmuBoard: return "macpro.gen1"
        case .powerManagement: return "bolt.fill"
        case .storage: return "internaldrive"
        case .battery: return "battery.100"
        case .smcGlobal: return "server.rack"
        case .unknown: return "thermometer.medium"
        }
    }
}
