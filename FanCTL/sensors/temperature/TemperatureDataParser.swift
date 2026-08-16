import Foundation

/// Parses raw SMC data corresponding to temperature.
enum TemperatureDataParser {
    /// Converts an `SMCDatum` into degrees Celsius according to the reported type.
    /// Supported formats: `sp78` (fixed point 8.8), `flt`, and a fallback for
    /// Apple Silicon models that do not report `dataType`.
    static func temperature(from datum: SMCDatum) -> Double? {
        let cleanType = datum.type.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = datum.bytes

        if cleanType == "sp78" && bytes.count >= 2 {
            let rawVal = (Int16(bytes[0]) << 8) | Int16(bytes[1])
            let temp = Double(rawVal) / 256.0
            if temp > 0 && temp < 130 {
                return temp
            }
        }

        if cleanType == "flt" && bytes.count >= 4 {
            let temp = Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
            if temp > 0 && temp < 130 {
                return temp
            }
        }

        // Some Apple Silicon models do not report dataType: try Float32 (host-endian)
        if cleanType.isEmpty && bytes.count >= 4 {
            let temp = Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
            if temp > 0 && temp < 130 {
                return temp
            }
        }

        return nil
    }
}
