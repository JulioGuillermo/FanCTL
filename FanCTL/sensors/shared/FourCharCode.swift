import Foundation

/// Utilities to encode/decode SMC FourCC keys ("FNum" <-> 0x464E756D).
enum FourCharCode {
    /// Converts a string of up to 4 ASCII characters into its `UInt32` value (big-endian).
    static func fromString(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    /// Converts a `UInt32` value into its 4-character ASCII representation.
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
