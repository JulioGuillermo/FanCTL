import Foundation

/// Constants of the AppleSMC communication protocol.
///
/// IMPORTANT: they must match the values defined in
/// `TemperatureBridge.h` (external method selector, commands and
/// result codes). They are centralized here in Swift to avoid the ambiguity
/// that arose from redefining the same names as the C header.
enum SMCConstants {
    /// External method selector used by `IOConnectCallStructMethod`.
    static let kernelIndex: UInt32 = 2

    /// SMC command to read a key's data (after `GET_KEY_INFO`).
    static let commandReadBytes: UInt8 = 5

    /// SMC command to write a key's data.
    static let commandWriteBytes: UInt8 = 6

    /// SMC command to get a key's information (size and type).
    static let commandGetKeyInfo: UInt8 = 9

    /// SMC command to iterate the key index by position.
    static let commandReadIndex: UInt8 = 8

    /// Success result returned by the SMC.
    static let success: UInt8 = 0
}
