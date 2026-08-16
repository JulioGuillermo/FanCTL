import Foundation
import IOKit

/// Low-level client for communicating with AppleSMC.
///
/// Opens an IOKit connection to the `AppleSMC` service and exposes reading of
/// firmware keys (two steps: `GET_KEY_INFO` to know size/type and
/// `READ_BYTES` to get the data). It is the only place that knows the
/// `SMCParamStruct` and the protocol constants.
final class SMCClient {
    private var connection: io_connect_t = 0

    /// Opens the connection to the AppleSMC service.
    /// - Returns: `true` if the connection became available for reading keys.
    @discardableResult
    func open() -> Bool {
        guard connection == 0 else { return true }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            AppLog.log("[SMCClient] Error: AppleSMC service not found.")
            return false
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != kIOReturnSuccess {
            AppLog.log("[SMCClient] IOServiceOpen failed: \(String(format: "0x%08x", result))")
            connection = 0
            return false
        }
        return true
    }

    /// Closes the connection to AppleSMC if it was open.
    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    /// Reads the raw data of an SMC key (e.g. "FNum", "Tp01").
    /// - Parameter key: 4-character key name.
    /// - Returns: raw key data, or `nil` if the key does not exist or reading fails.
    func readKeyData(_ key: String) -> SMCDatum? {
        let keyCode = FourCharCode.fromString(key)

        var inputInfo = SMCParamStruct()
        var outputInfo = SMCParamStruct()

        inputInfo.key = keyCode
        inputInfo.data8 = SMCConstants.commandGetKeyInfo

        guard callStruct(input: &inputInfo, output: &outputInfo) else {
            return nil
        }

        let dataSize = outputInfo.keyInfo.dataSize
        let dataType = FourCharCode.toString(outputInfo.keyInfo.dataType)
        guard dataSize > 0 else { return nil }

        var inputRead = SMCParamStruct()
        var outputRead = SMCParamStruct()

        inputRead.key = keyCode
        inputRead.keyInfo.dataSize = dataSize
        inputRead.data8 = SMCConstants.commandReadBytes

        guard callStruct(input: &inputRead, output: &outputRead) else {
            return nil
        }

        let bytes = withUnsafeBytes(of: outputRead.bytes) {
            Array($0.prefix(Int(dataSize)))
        }
        return SMCDatum(bytes: bytes, type: dataType, size: dataSize)
    }

    /// Writes raw data to an SMC key (e.g. "F0Md", "F0Mn").
    /// - Parameters:
    ///   - key: 4-character key name.
    ///   - bytes: Data to write (size according to the key's type).
    /// - Returns: `true` if the write completed successfully.
    @discardableResult
    func writeKeyData(_ key: String, bytes: [UInt8]) -> Bool {
        let keyCode = FourCharCode.fromString(key)

        var inputInfo = SMCParamStruct()
        var outputInfo = SMCParamStruct()

        inputInfo.key = keyCode
        inputInfo.data8 = SMCConstants.commandGetKeyInfo

        guard callStruct(input: &inputInfo, output: &outputInfo) else { return false }

        let dataSize = Int(outputInfo.keyInfo.dataSize)
        guard dataSize > 0 else { return false }

        var inputWrite = SMCParamStruct()
        var outputWrite = SMCParamStruct()

        inputWrite.key = keyCode
        inputWrite.data8 = SMCConstants.commandWriteBytes
        inputWrite.keyInfo.dataSize = outputInfo.keyInfo.dataSize

        let count = min(bytes.count, dataSize)
        withUnsafeMutableBytes(of: &inputWrite.bytes) { raw in
            raw.baseAddress?.copyMemory(from: bytes, byteCount: count)
        }

        return callStruct(input: &inputWrite, output: &outputWrite)
    }

    private func callStruct(input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let result = IOConnectCallStructMethod(
            connection,
            SMCConstants.kernelIndex,
            &input,
            inputSize,
            &output,
            &outputSize
        )
        if result != kIOReturnSuccess {
            AppLog.log("[SMCClient] callSMC failed: kr=\(String(format: "0x%08x", result))")
            return false
        }
        return output.result == SMCConstants.success
    }
}
