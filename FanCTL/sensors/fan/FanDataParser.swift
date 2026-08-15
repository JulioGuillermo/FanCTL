import Foundation

/// Parsea los datos crudos del SMC correspondientes a velocidad de ventilador.
enum FanDataParser {
    /// Convierte un `SMCDatum` en RPM según el tipo reportado.
    /// Formatos soportados: `flt`, `fpe2`, `ui16`, `ui8`, más un fallback para
    /// modelos Apple Silicon que no reportan `dataType`.
    static func rpm(from datum: SMCDatum) -> Double? {
        let cleanType = datum.type.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = datum.bytes

        // Formato flt: Float32 IEEE-754 de 4 bytes. En Apple Silicon se guarda en
        // endianness nativo del host (little-endian en este hardware).
        if cleanType == "flt" && bytes.count >= 4 {
            let f = bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
            return Double(f)
        }
        // Formato fpe2: Fixed Point 14.2 (Intel, big-endian: valor crudo dividido entre 4)
        if cleanType == "fpe2" && bytes.count >= 2 {
            let rawVal = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(rawVal) / 4.0
        }
        // Formato ui16: Entero sin signo de 16 bits
        if cleanType == "ui16" && bytes.count >= 2 {
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        }
        // Formato ui8: Entero sin signo de 8 bits
        if cleanType == "ui8" && bytes.count >= 1 {
            return Double(bytes[0])
        }
        // Algunos modelos Apple Silicon no reportan dataType: intentar Float32 (host-endian)
        if cleanType.isEmpty && bytes.count == 4 {
            let f = bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
            if f.isFinite && f >= 0 && f < 100000 { return Double(f) }
        }
        // Fallback de 2 bytes si el tipo no coincide exactamente
        if bytes.count == 2 {
            let rawVal = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(rawVal) / 4.0
        }
        return nil
    }
}
