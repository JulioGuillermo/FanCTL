import Foundation

/// Parses raw SMC data corresponding to fan speed.
enum FanDataParser {
    /// Converts an `SMCDatum` into RPM according to the reported type.
    /// Supported formats: `flt`, `fpe2`, `ui16`, `ui8`, plus a fallback for
    /// Apple Silicon models that do not report `dataType`.
    static func rpm(from datum: SMCDatum) -> Double? {
        let cleanType = datum.type.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = datum.bytes

        // flt format: 4-byte IEEE-754 Float32. On Apple Silicon it is stored in
        // the host's native endianness (little-endian on this hardware).
        if cleanType == "flt" && bytes.count >= 4 {
            let f = bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
            return Double(f)
        }
        // fpe2 format: Fixed Point 14.2 (Intel, big-endian: raw value divided by 4)
        if cleanType == "fpe2" && bytes.count >= 2 {
            let rawVal = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(rawVal) / 4.0
        }
        // ui16 format: unsigned 16-bit integer
        if cleanType == "ui16" && bytes.count >= 2 {
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        }
        // ui8 format: unsigned 8-bit integer
        if cleanType == "ui8" && bytes.count >= 1 {
            return Double(bytes[0])
        }
        // Some Apple Silicon models do not report dataType: try Float32 (host-endian)
        if cleanType.isEmpty && bytes.count == 4 {
            let f = bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
            if f.isFinite && f >= 0 && f < 100000 { return Double(f) }
        }
        // 2-byte fallback if the type does not match exactly
        if bytes.count == 2 {
            let rawVal = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(rawVal) / 4.0
        }
        return nil
    }
}
