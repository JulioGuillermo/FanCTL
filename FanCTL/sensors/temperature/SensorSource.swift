import Foundation

/// Sensor read source of a sensor.
enum SensorSource: String, Codable {
    case smc = "SMC (AppleSMC)"
    case hid = "IOHID (ThermalZone)"
}
