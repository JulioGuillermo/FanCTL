import Foundation

/// Constantes del protocolo de comunicación con AppleSMC.
///
/// IMPORTANTE: deben coincidir con los valores definidos en
/// `TemperatureBridge.h` (selector del método externo, comandos y códigos
/// de resultado). Se centralizan aquí en Swift para evitar la ambigüedad
/// que se producía al redefinir los mismos nombres que el header C.
enum SMCConstants {
    /// Selector de método externo usado por `IOConnectCallStructMethod`.
    static let kernelIndex: UInt32 = 2

    /// Comando SMC para leer los datos de una clave (tras `GET_KEY_INFO`).
    static let commandReadBytes: UInt8 = 5

    /// Comando SMC para obtener la información de una clave (tamaño y tipo).
    static let commandGetKeyInfo: UInt8 = 9

    /// Comando SMC para recorrer el índice de claves por posición.
    static let commandReadIndex: UInt8 = 8

    /// Resultado de éxito devuelto por el SMC.
    static let success: UInt8 = 0
}
