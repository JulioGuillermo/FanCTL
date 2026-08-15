import Foundation
import IOKit

/// Cliente de bajo nivel de comunicación con AppleSMC.
///
/// Abre una conexión IOKit con el servicio `AppleSMC` y expone la lectura de
/// claves del firmware (dos pasos: `GET_KEY_INFO` para conocer tamaño/tipo y
/// `READ_BYTES` para obtener los datos). Es el único punto que conoce el
/// `SMCParamStruct` y las constantes del protocolo.
final class SMCClient {
    private var connection: io_connect_t = 0

    /// Abre la conexión con el servicio AppleSMC.
    /// - Returns: `true` si la conexión quedó disponible para leer claves.
    @discardableResult
    func open() -> Bool {
        guard connection == 0 else { return true }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            AppLog.log("[SMCClient] Error: No se encontró el servicio AppleSMC.")
            return false
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != kIOReturnSuccess {
            AppLog.log("[SMCClient] IOServiceOpen falló: \(String(format: "0x%08x", result))")
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

    /// Lee los datos crudos de una clave del SMC (ej. "FNum", "Tp01").
    /// - Parameter key: Nombre de la clave de 4 caracteres.
    /// - Returns: Datos crudos de la clave, o `nil` si la clave no existe o falla la lectura.
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

    /// Escribe datos crudos en una clave del SMC (ej. "F0Md", "F0Mn").
    /// - Parameters:
    ///   - key: Nombre de la clave de 4 caracteres.
    ///   - bytes: Datos a escribir (tamaño según el tipo de la clave).
    /// - Returns: `true` si la escritura se completó correctamente.
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
            AppLog.log("[SMCClient] callSMC falló: kr=\(String(format: "0x%08x", result))")
            return false
        }
        return output.result == SMCConstants.success
    }
}
