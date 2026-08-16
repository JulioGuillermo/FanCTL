import Foundation

/// Complete structure of information and metadata of a hardware sensor.
struct SensorInfo: Identifiable, Hashable {
    let id: String              // Unique identifier (e.g. "PMU2 tdie1")
    let rawKey: String          // Raw name or key in IOKit/SMC
    let value: Double           // Reading (degrees Celsius, watts or volts)
    let source: SensorSource    // Source of the reading (SMC or HID)
    let category: SensorCategory// Assigned category
    let thermalZone: String?    // Thermal zone reported by IOKit (if any)
    let usagePage: Int?         // HID Usage Page (ej. 0xFF00)
    let usage: Int?             // HID Usage (e.g. 5 for Temperature)
    let descriptionText: String // Technical explanation of the sensor
    let unit: String            // Measurement unit ("°C", "W" or "V")

    /// Whether the reading is a temperature (used for max-temp and fan logic).
    var isTemperature: Bool { unit == "°C" }

    /// Reading formatted with its unit, e.g. "46.5 °C" or "6.7 W".
    var displayValue: String {
        String(format: "%.1f %@", value, unit)
    }
}
