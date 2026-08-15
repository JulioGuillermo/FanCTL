import Foundation

/// Utilidades para codificar/decodificar claves FourCC del SMC ("FNum" <-> 0x464E756D).
enum FourCharCode {
    /// Convierte un string de hasta 4 caracteres ASCII en su valor `UInt32` (big-endian).
    static func fromString(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    /// Convierte un valor `UInt32` en su representación ASCII de 4 caracteres.
    static func toString(_ code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}
