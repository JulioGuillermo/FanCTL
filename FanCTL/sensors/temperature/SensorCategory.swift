import Foundation

/// Visual/functional category of the sensor.
enum SensorCategory: String, Codable, CaseIterable {
    case socDie = "SoC Die (CPU/GPU Core)"
    case gpu = "GPU / Graphics"
    case memory = "Memory (RAM)"
    case pmuBoard = "PMU / Motherboard"
    case powerManagement = "Power management"
    case storage = "Storage (SSD)"
    case battery = "Battery / Power"
    case smcGlobal = "SMC / Legacy firmware"
    case power = "Power (Watts)"
    case voltage = "Voltage (Volts)"
    case unknown = "Other sensors"

    var iconName: String {
        switch self {
        case .socDie: return "cpu"
        case .gpu: return "square.3.layers.3d"
        case .memory: return "memorychip"
        case .pmuBoard: return "macpro.gen1"
        case .powerManagement: return "bolt.fill"
        case .storage: return "internaldrive"
        case .battery: return "battery.100"
        case .smcGlobal: return "server.rack"
        case .power: return "bolt.fill"
        case .voltage: return "bolt.badge.a"
        case .unknown: return "thermometer.medium"
        }
    }
}
