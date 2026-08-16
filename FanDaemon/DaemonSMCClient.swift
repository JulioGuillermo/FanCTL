import Foundation
import IOKit

/// Minimal file logger for the daemon (runs as root, so it cannot use the
/// user's ~/Library). Writes to /Library/Logs/FanCTL/fanctl-daemon.log
enum DaemonLog {
    private static let fileURL: URL = {
        let dir = URL(fileURLWithPath: "/Library/Logs/FanCTL", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("fanctl-daemon.log")
    }()

    private static let lock = NSLock()

    static func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}

/// Low-level AppleSMC client for writing (manual mode + speed).
///
/// It is a reduced version of the app's `SMCClient`: it only needs the
/// write path (GET_KEY_INFO → WRITE_BYTES) and its own log, without depending on the
/// rest of the project.
final class DaemonSMCClient {
    private var connection: io_connect_t = 0

    /// AppleSMC external method selector.
    private let kernelIndex: UInt32 = 2

    /// SMC write command (not defined in TemperatureBridge.h).
    private let commandWriteBytes: UInt8 = 6

    /// Opens the connection to the AppleSMC service.
    @discardableResult
    func open() -> Bool {
        guard connection == 0 else { return true }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            DaemonLog.log("[DaemonSMCClient] Error: AppleSMC service not found.")
            return false
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != kIOReturnSuccess {
            DaemonLog.log("[DaemonSMCClient] IOServiceOpen failed: \(String(format: "0x%08x", result))")
            connection = 0
            return false
        }
        return true
    }

    /// Closes the AppleSMC connection if it was open.
    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    /// Sets a fan to the given speed (Apple Silicon: key `F{N}Tg`).
    /// - Returns: `true` if the speed write completed.
    func setFanSpeed(fanIndex: Int, rpm: Double) -> Bool {
        let key = "F\(fanIndex)"
        // Manual mode: helps to fix the value, but may be rejected (error 130)
        // on Apple Silicon; it is non-blocking.
        if writeKey(key + "Md", bytes: [1]) {
            DaemonLog.log("[DaemonSMCClient] F\(fanIndex) manual mode OK")
        } else {
            DaemonLog.log("[DaemonSMCClient] F\(fanIndex) manual mode rejected (non-blocking)")
        }
        let fltBytes = withUnsafeBytes(of: Float(rpm)) { Array($0) }
        if writeKey(key + "Tg", bytes: fltBytes) {
            return true
        }
        DaemonLog.log("[DaemonSMCClient] Could not write the speed to \(key)Tg.")
        return false
    }

    /// Returns a fan to system control (automatic mode).
    /// On Apple Silicon automatic mode is observed as `F{N}Md = 3`.
    func restoreSystemControl(fanIndex: Int) -> Bool {
        let key = "F\(fanIndex)"
        if writeKey(key + "Md", bytes: [0]) {
            return true
        }
        DaemonLog.log("[DaemonSMCClient] F\(fanIndex) auto=0 rejected, trying auto=3")
        return writeKey(key + "Md", bytes: [3])
    }

    /// Diagnostics: dumps the known keys of fan 0.
    func dumpFanKeys() {
        for suffix in ["Md", "Mn", "Ac", "Tg"] {
            let key = "F0" + suffix
            if let info = keyInfo(key) {
                DaemonLog.log("[DaemonSMCClient] \(key): dataSize=\(info.dataSize) type=\(typeString(info.dataType))")
            } else {
                DaemonLog.log("[DaemonSMCClient] \(key): GET_KEY_INFO failed or dataSize=0")
            }
        }
    }

    private func typeString(_ type: FourCharCode) -> String {
        var code = type.bigEndian
        let s = withUnsafeBytes(of: &code) { raw in
            String(decoding: raw, as: UTF8.self)
        }
        return s
    }

    private func keyInfo(_ key: String) -> (dataSize: Int, dataType: FourCharCode)? {
        let keyCode = UInt32(smcKey: key)
        var inputInfo = SMCParamStruct()
        var outputInfo = SMCParamStruct()
        inputInfo.key = keyCode
        inputInfo.data8 = UInt8(kSMCCmdGetKeyInfo)
        guard callStruct(input: &inputInfo, output: &outputInfo) else { return nil }
        let dataSize = Int(outputInfo.keyInfo.dataSize)
        guard dataSize > 0 else { return nil }
        return (dataSize, outputInfo.keyInfo.dataType)
    }

    /// Writes raw data to an SMC key (e.g. "F0Md", "F0Mn").
    @discardableResult
    func writeKey(_ key: String, bytes: [UInt8]) -> Bool {
        let keyCode = UInt32(smcKey: key)

        var inputInfo = SMCParamStruct()
        var outputInfo = SMCParamStruct()

        inputInfo.key = keyCode
        inputInfo.data8 = UInt8(kSMCCmdGetKeyInfo)

        guard callStruct(input: &inputInfo, output: &outputInfo) else { return false }

        let dataSize = Int(outputInfo.keyInfo.dataSize)
        guard dataSize > 0 else {
            DaemonLog.log("[DaemonSMCClient] \(key): GET_KEY_INFO ok but dataSize=0")
            return false
        }

        var inputWrite = SMCParamStruct()
        var outputWrite = SMCParamStruct()

        inputWrite.key = keyCode
        inputWrite.data8 = commandWriteBytes
        inputWrite.keyInfo.dataSize = outputInfo.keyInfo.dataSize

        let count = min(bytes.count, dataSize)
        withUnsafeMutableBytes(of: &inputWrite.bytes) { raw in
            raw.baseAddress?.copyMemory(from: bytes, byteCount: count)
        }

        if callStruct(input: &inputWrite, output: &outputWrite) {
            return true
        }
        DaemonLog.log("[DaemonSMCClient] \(key): write rejected (result=\(outputWrite.result), dataSize=\(dataSize))")
        return false
    }

    private func callStruct(input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let result = IOConnectCallStructMethod(
            connection,
            kernelIndex,
            &input,
            inputSize,
            &output,
            &outputSize
        )
        if result != kIOReturnSuccess {
            DaemonLog.log("[DaemonSMCClient] callSMC failed: kr=\(String(format: "0x%08x", result))")
            return false
        }
        return output.result == UInt8(kSMCSuccess)
    }
}

private extension UInt32 {
    /// Converts a 4-character key (e.g. "F0Md") into its 32-bit representation.
    init(smcKey: String) {
        var value: UInt32 = 0
        for (i, char) in smcKey.prefix(4).utf8.enumerated() {
            value |= UInt32(char) << (8 * (3 - i))
        }
        self = value
    }
}
