import Foundation
import IOKit

/// Servicio encargado de escanear y comunicarse con el SMC para obtener datos de ventiladores
class FanScanner {
    private var connection: io_connect_t = 0

    private func stringToFourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    private func fourCharCodeToString(_ code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }

    func openConnection() -> Bool {
        AppLog.log("[FanScanner] Abriendo conexión con AppleSMC...")
        let mainPort: mach_port_t = 0
        let service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            print("[-][FanScanner] Error: No se encontró el servicio AppleSMC.")
            AppLog.log("[-][FanScanner] Error: No se encontró el servicio AppleSMC.")
            return false
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != kIOReturnSuccess {
            print("[-][FanScanner] IOServiceOpen falló con código: \(String(format: "0x%08x", result))")
            AppLog.log("[-][FanScanner] IOServiceOpen falló con código: \(String(format: "0x%08x", result))")
            return false
        }
        AppLog.log("[FanScanner] Conexión AppleSMC OK (connection=\(connection))")
        return true
    }

    func closeConnection() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    private func callSMC(input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
        var inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let result = IOConnectCallStructMethod(
            connection,
            UInt32(KKERNEL_INDEX_SMC),
            &input,
            inputSize,
            &output,
            &outputSize
        )
        if result != kIOReturnSuccess || output.result != UInt8(kSMCSuccess) {
            AppLog.log("[FanScanner] callSMC falló: kr=\(String(format: "0x%08x", result)) res=\(output.result)")
            return false
        }
        return true
    }

    private func readSMCKeyData(key: String) -> (bytes: [UInt8], type: String, size: UInt32)? {
        let keyCode = stringToFourCharCode(key)
        
        var inputInfo = SMCParamStruct()
        var outputInfo = SMCParamStruct()
        
        inputInfo.key = keyCode
        inputInfo.data8 = UInt8(kSMCCmdGetKeyInfo)
        
        guard callSMC(input: &inputInfo, output: &outputInfo), outputInfo.result == UInt8(kSMCSuccess) else {
            AppLog.log("[FanScanner] GET_KEY_INFO \(key) falló: res=\(outputInfo.result)")
            return nil
        }
        
        let dataSize = outputInfo.keyInfo.dataSize
        let dataType = fourCharCodeToString(outputInfo.keyInfo.dataType)
        
        guard dataSize > 0 else { return nil }
        
        var inputRead = SMCParamStruct()
        var outputRead = SMCParamStruct()
        
        inputRead.key = keyCode
        inputRead.keyInfo.dataSize = dataSize
        inputRead.data8 = UInt8(kSMCCmdReadBytes)
        
        guard callSMC(input: &inputRead, output: &outputRead), outputRead.result == UInt8(kSMCSuccess) else {
            return nil
        }
        
        let byteArray = withUnsafeBytes(of: outputRead.bytes) {
            Array($0.prefix(Int(dataSize)))
        }
        return (byteArray, dataType, dataSize)
    }

    private func parseFanRPM(_ data: (bytes: [UInt8], type: String, size: UInt32)) -> Double? {
        let cleanType = data.type.trimmingCharacters(in: .whitespacesAndNewlines)

        // Formato flt: Float32 IEEE-754 de 4 bytes. En Apple Silicon se guarda en
        // endianness nativo del host (little-endian en este hardware).
        if cleanType == "flt" && data.bytes.count >= 4 {
            let f = data.bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
            return Double(f)
        }
        // Formato fpe2: Fixed Point 14.2 (Intel, big-endian: valor crudo dividido entre 4)
        if cleanType == "fpe2" && data.bytes.count >= 2 {
            let rawVal = (UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1])
            return Double(rawVal) / 4.0
        }
        // Formato ui16: Entero sin signo de 16 bits
        if cleanType == "ui16" && data.bytes.count >= 2 {
            return Double((UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1]))
        }
        // Formato ui8: Entero sin signo de 8 bits
        if cleanType == "ui8" && data.bytes.count >= 1 {
            return Double(data.bytes[0])
        }
        // Algunos modelos Apple Silicon no reportan dataType: intentar Float32 (host-endian)
        if cleanType.isEmpty && data.bytes.count == 4 {
            let f = data.bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
            if f.isFinite && f >= 0 && f < 100000 { return Double(f) }
        }
        // Fallback de 2 bytes si el tipo no coincide exactamente
        if data.bytes.count == 2 {
            let rawVal = (UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1])
            return Double(rawVal) / 4.0
        }
        return nil
    }

    private func readFanValue(key: String) -> Double? {
        guard let data = readSMCKeyData(key: key) else { return nil }
        return parseFanRPM(data)
    }

    /// Obtiene la lista completa de ventiladores instalados y sus métricas
    func getAllFans() -> [FanInfo] {
        guard openConnection() else { return [] }
        defer { closeConnection() }

        var fansList: [FanInfo] = []

        // 1. Obtener la cantidad total de ventiladores leyendo la clave 'FNum'
        var fanCount = 0
        if let numData = readSMCKeyData(key: "FNum"), !numData.bytes.isEmpty {
            fanCount = Int(numData.bytes[0])
        }

        // Fallback: Si FNum devuelve 0, sondear directamente la existencia de claves F0Ac, F1Ac...
        if fanCount == 0 {
            for i in 0..<4 {
                if readSMCKeyData(key: "F\(i)Ac") != nil {
                    fanCount = i + 1
                } else {
                    break
                }
            }
        }

        print("[FanScanner] Ventiladores físicos detectados: \(fanCount)")
        AppLog.log("[FanScanner] Ventiladores físicos detectados: \(fanCount)")

        // 2. Si existen ventiladores, iterar leyendo las claves de cada uno
        for i in 0..<fanCount {
            let actualKey = "F\(i)Ac"
            let minKey    = "F\(i)Mn"
            let maxKey    = "F\(i)Mx"
            let targetKey = "F\(i)Tg"

            let actual = readFanValue(key: actualKey) ?? 0.0
            let minVal = readFanValue(key: minKey) ?? 1200.0
            let maxVal = readFanValue(key: maxKey) ?? 5000.0
            let target = readFanValue(key: targetKey)

            let fanName = fanCount == 1 ? "Ventilador Principal" : "Ventilador \(i + 1)"

            fansList.append(FanInfo(
                id: i,
                name: fanName,
                currentRPM: actual,
                minRPM: minVal,
                maxRPM: maxVal,
                targetRPM: target,
                mode: .automatic
            ))
        }

        return fansList
    }
}