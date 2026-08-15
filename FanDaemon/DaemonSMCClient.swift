import Foundation
import IOKit

/// Logger mínimo a archivo para el daemon (corre como root, así que no puede
/// usar ~/Library del usuario). Escribe en /Library/Logs/FanCTL/fanctl-daemon.log
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

/// Cliente de bajo nivel de AppleSMC para escritura (modo manual + velocidad).
///
/// Es una versión reducida de `SMCClient` de la app: solo necesita el camino
/// de escritura (GET_KEY_INFO → WRITE_BYTES) y un log propio, sin depender del
/// resto del proyecto.
final class DaemonSMCClient {
    private var connection: io_connect_t = 0

    /// Selector del método externo de AppleSMC.
    private let kernelIndex: UInt32 = 2

    /// Comando SMC de escritura (no definido en TemperatureBridge.h).
    private let commandWriteBytes: UInt8 = 6

    /// Abre la conexión con el servicio AppleSMC.
    @discardableResult
    func open() -> Bool {
        guard connection == 0 else { return true }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            DaemonLog.log("[DaemonSMCClient] Error: No se encontró el servicio AppleSMC.")
            return false
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != kIOReturnSuccess {
            DaemonLog.log("[DaemonSMCClient] IOServiceOpen falló: \(String(format: "0x%08x", result))")
            connection = 0
            return false
        }
        return true
    }

    /// Cierra la conexión con AppleSMC si estaba abierta.
    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    /// Fija un ventilador a la velocidad indicada (Apple Silicon: clave `F{N}Tg`).
    /// - Returns: `true` si la escritura de velocidad se completó.
    func setFanSpeed(fanIndex: Int, rpm: Double) -> Bool {
        let key = "F\(fanIndex)"
        // Modo manual: ayuda a fijar el valor, pero puede ser rechazado (error 130)
        // en Apple Silicon; no es bloqueante.
        if writeKey(key + "Md", bytes: [1]) {
            DaemonLog.log("[DaemonSMCClient] F\(fanIndex) modo manual OK")
        } else {
            DaemonLog.log("[DaemonSMCClient] F\(fanIndex) modo manual rechazado (no bloqueante)")
        }
        let fltBytes = withUnsafeBytes(of: Float(rpm)) { Array($0) }
        if writeKey(key + "Tg", bytes: fltBytes) {
            return true
        }
        DaemonLog.log("[DaemonSMCClient] No se pudo escribir la velocidad en \(key)Tg.")
        return false
    }

    /// Devuelve un ventilador al control del sistema (modo automático).
    /// En Apple Silicon el modo automático se observa como `F{N}Md = 3`.
    func restoreSystemControl(fanIndex: Int) -> Bool {
        let key = "F\(fanIndex)"
        if writeKey(key + "Md", bytes: [0]) {
            return true
        }
        DaemonLog.log("[DaemonSMCClient] F\(fanIndex) auto=0 rechazado, probando auto=3")
        return writeKey(key + "Md", bytes: [3])
    }

    /// Diagnóstico: vuelca las claves conocidas del ventilador 0.
    func dumpFanKeys() {
        for suffix in ["Md", "Mn", "Ac", "Tg"] {
            let key = "F0" + suffix
            if let info = keyInfo(key) {
                DaemonLog.log("[DaemonSMCClient] \(key): dataSize=\(info.dataSize) type=\(typeString(info.dataType))")
            } else {
                DaemonLog.log("[DaemonSMCClient] \(key): GET_KEY_INFO falló o dataSize=0")
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

    /// Escribe datos crudos en una clave del SMC (ej. "F0Md", "F0Mn").
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
            DaemonLog.log("[DaemonSMCClient] \(key): GET_KEY_INFO ok pero dataSize=0")
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
        DaemonLog.log("[DaemonSMCClient] \(key): escritura rechazada (result=\(outputWrite.result), dataSize=\(dataSize))")
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
            DaemonLog.log("[DaemonSMCClient] callSMC falló: kr=\(String(format: "0x%08x", result))")
            return false
        }
        return output.result == UInt8(kSMCSuccess)
    }
}

private extension UInt32 {
    /// Convierte una clave de 4 caracteres (ej. "F0Md") en su representación de 32 bits.
    init(smcKey: String) {
        var value: UInt32 = 0
        for (i, char) in smcKey.prefix(4).utf8.enumerated() {
            value |= UInt32(char) << (8 * (3 - i))
        }
        self = value
    }
}
