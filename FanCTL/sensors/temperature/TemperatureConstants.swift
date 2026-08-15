//
//  SMCConstants.swift
//  FanCTL
//

import IOKit

// Constantes para comunicación con AppleSMC
public let KKERNEL_INDEX_SMC: UInt32 = 0

// Comandos SMC
public let kSMCCmdReadBytes: UInt8 = 254
public let kSMCCmdGetKeyInfo: UInt8 = 251
public let kSMCCmdReadIndex: UInt8 = 253

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
