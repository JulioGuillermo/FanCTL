//
//  SMCConstants.swift
//  FanCTL
//

import IOKit

// Constantes para comunicación con AppleSMC.
// IMPORTANTE: deben coincidir con los valores del header C (TemperatureBridge.h).
// Los valores antiguos (0, 251, 254, 253) hacían que el driver respondiera
// kIOReturnSuccess sin escribir nada (salida a ceros) y ningún ventilador/sensor SMC se leyera.

public let KKERNEL_INDEX_SMC: UInt32 = 2

// Comandos SMC
public let kSMCCmdReadBytes: UInt8 = 5
public let kSMCCmdGetKeyInfo: UInt8 = 9
public let kSMCCmdReadIndex: UInt8 = 8

// Resultados
public let kSMCSuccess: UInt8 = 0

// Constantes de IOKit (definidas manualmente)
public var kIOMainPortDefault: io_object_t {
    return io_object_t(MACH_PORT_NULL)
}

// Tipos necesarios para IOKit
@objc public enum IOStatus : Int {
    case success = 32768 // 0x8001
}

public let IOStatusSuccess: IOStatus = .success
