import Foundation

/// Parses raw SMC data into a numeric reading (temperature, power or voltage).
enum TemperatureDataParser {
    /// Converts an `SMCDatum` into degrees Celsius according to the reported type.
    /// Supported formats: `sp78` (fixed point 8.8), `flt`, and a fallback for
    /// Apple Silicon models that do not report `dataType`.
    static func temperature(from datum: SMCDatum) -> Double? {
        value(from: datum, unit: "°C")
    }

    /// Decodes the numeric value of an `SMCDatum`.
    /// - Parameters:
    ///   - datum: raw SMC data.
    ///   - unit: `"°C"` applies a sanity range check (0...130 °C), other units
    ///           accept any value (a dead rail legitimately reads 0 W / 0 V).
    static func value(from datum: SMCDatum, unit: String) -> Double? {
        let cleanType = datum.type.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = datum.bytes
        var value: Double?

        if cleanType == "flt" && bytes.count >= 4 {
            value = Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
        } else if cleanType == "sp78" && bytes.count >= 2 {
            let rawVal = (Int16(bytes[0]) << 8) | Int16(bytes[1])
            value = Double(rawVal) / 256.0
        } else if cleanType == "fpe2" && bytes.count >= 2 {
            let rawVal = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            value = Double(rawVal) / 16384.0
        } else if cleanType == "fpe4" && bytes.count >= 2 {
            let rawVal = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            value = Double(rawVal) / 4096.0
        }

        // Some Apple Silicon models do not report dataType: try Float32 (host-endian)
        if value == nil && cleanType.isEmpty && bytes.count >= 4 {
            value = Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
        }

        guard let result = value, result.isFinite else { return nil }

        // Temperatures are physically bounded; power/voltage readings can be 0.
        if unit == "°C" && (result <= 0 || result >= 130) {
            return nil
        }
        return result
    }
}
