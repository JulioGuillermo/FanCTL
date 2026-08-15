import Foundation

/// Parsea los datos crudos del SMC correspondientes a temperatura.
enum TemperatureDataParser {
    /// Convierte un `SMCDatum` en grados Celsius según el tipo reportado.
    /// Formatos soportados: `sp78` (fixed point 8.8), `flt`, y un fallback para
    /// modelos Apple Silicon que no reportan `dataType`.
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

        // Algunos modelos Apple Silicon no reportan dataType: intentar Float32 (host-endian)
        if cleanType.isEmpty && bytes.count >= 4 {
            let temp = Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
            if temp > 0 && temp < 130 {
                return temp
            }
        }

        return nil
    }
}
