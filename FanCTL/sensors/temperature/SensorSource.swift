import Foundation

/// Origen de la lectura de un sensor.
enum SensorSource: String, Codable {
    case smc = "SMC (AppleSMC)"
    case hid = "IOHID (ThermalZone)"
}
