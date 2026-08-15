import Foundation
import IOKit

// Categoría visual/funcional del sensor
enum SensorCategory: String, Codable, CaseIterable {
    case socDie = "SoC Die (CPU/GPU Core)"
    case pmuBoard = "PMU / Placa Madre"
    case battery = "Batería / Alimentación"
    case smcGlobal = "SMC / Firmware Legacy"
    case unknown = "Otros Sensores"
    
    var iconName: String {
        switch self {
        case .socDie: return "cpu"
        case .pmuBoard: return "memorychip"
        case .battery: return "battery.100"
        case .smcGlobal: return "server.rack"
        case .unknown: return "thermometer.medium"
        }
    }
}

enum SensorSource: String, Codable {
    case smc = "SMC (AppleSMC)"
    case hid = "IOHID (ThermalZone)"
}

// Estructura completa de información y metadatos del sensor
struct SensorInfo: Identifiable, Hashable {
    let id: String              // Identificador único (ej. "PMU2 tdie1")
    let rawKey: String          // Nombre o clave cruda en IOKit/SMC
    let value: Double           // Lectura en grados Celsius
    let source: SensorSource    // Origen de la lectura (SMC o HID)
    let category: SensorCategory// Categoría asignada
    let thermalZone: String?    // Zona térmica reportada por IOKit (si existe)
    let usagePage: Int?         // HID Usage Page (ej. 0xFF00)
    let usage: Int?             // HID Usage (ej. 5 para Temperatura)
    let descriptionText: String // Explicación técnica del sensor
}

class SMCScanner {
    private var connection: io_connect_t = 0

    private func stringToFourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    private func fourCharCodeToString(_ code: UInt32) -> String {
        let bigEndianCode = code.bigEndian
        let bytes = [
            UInt8((bigEndianCode >> 24) & 0xFF),
            UInt8((bigEndianCode >> 16) & 0xFF),
            UInt8((bigEndianCode >> 8) & 0xFF),
            UInt8(bigEndianCode & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }

    func openConnection() -> Bool {
        print("[SMC] Buscando servicio AppleSMC...")
        let mainPort: mach_port_t = 0
        let service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            print("[-] Error: No se encontró el servicio AppleSMC en IOKit.")
            return false
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != kIOReturnSuccess {
            let hexCode = String(format: "0x%08x", result)
            print("[-] IOServiceOpen falló con código: \(hexCode)")
            return false
        }
        print("[+] Conexión establecida con AppleSMC correctamente.")
        return true
    }

    func closeConnection() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
            print("[SMC] Conexión cerrada.")
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
        return result == kIOReturnSuccess && output.result == UInt8(kSMCSuccess)
    }

    private func readSMCKeyData(key: String) -> (bytes: [UInt8], type: String, size: UInt32)? {
        let keyCode = stringToFourCharCode(key)
        
        var inputInfo = SMCParamStruct()
        var outputInfo = SMCParamStruct()
        
        inputInfo.key = keyCode
        inputInfo.data8 = UInt8(kSMCCmdGetKeyInfo)
        
        guard callSMC(input: &inputInfo, output: &outputInfo), outputInfo.result == UInt8(kSMCSuccess) else {
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
        
        let mirror = Mirror(reflecting: outputRead.bytes)
        let byteArray = mirror.children.prefix(Int(dataSize)).compactMap { $0.value as? UInt8 }
        
        return (byteArray, dataType, dataSize)
    }

    // Parsea los datos numéricos de velocidad del ventilador (fpe2, flt, ui16, ui32)
    private func parseFanRPM(_ data: (bytes: [UInt8], type: String, size: UInt32)) -> Double? {
        if data.type == "fpe2" && data.bytes.count >= 2 {
            let rawVal = (UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1])
            return Double(rawVal) / 4.0
        }
        if data.type == "flt " && data.bytes.count >= 4 {
            let u32Val = (UInt32(data.bytes[0]) << 24) |
                         (UInt32(data.bytes[1]) << 16) |
                         (UInt32(data.bytes[2]) << 8)  |
                         UInt32(data.bytes[3])
            return Double(Float(bitPattern: u32Val))
        }
        if data.type == "ui16" && data.bytes.count >= 2 {
            return Double((UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1]))
        }
        return nil
    }

    private func readFanValue(key: String) -> Double? {
        guard let data = readSMCKeyData(key: key) else { return nil }
        return parseFanRPM(data)
    }

    private func readTemperatureKey(_ key: String) -> Double? {
        guard let data = readSMCKeyData(key: key) else { return nil }
        
        if data.type == "sp78" && data.bytes.count >= 2 {
            let rawVal = (Int16(data.bytes[0]) << 8) | Int16(data.bytes[1])
            let temp = Double(rawVal) / 256.0
            if temp > 0 && temp < 130 {
                return temp
            }
        }
        
        if data.type == "flt " && data.bytes.count >= 4 {
            let u32Val = (UInt32(data.bytes[0]) << 24) |
                         (UInt32(data.bytes[1]) << 16) |
                         (UInt32(data.bytes[2]) << 8)  |
                         UInt32(data.bytes[3])
            let temp = Float(bitPattern: u32Val)
            let tempDouble = Double(temp)
            if tempDouble > 0 && tempDouble < 130 {
                return tempDouble
            }
        }
        
        return nil
    }

    private var knownAppleSiliconKeys: [String] {
        return [
            "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0T", "Tp0P",
            "TG0b", "TG0d", "TG0P",
            "TB0T", "TB1T", "TB2T",
            "TM0P", "TM0S", "Th0H", "Th1H",
            "F0Ac", "F1Ac"
        ]
    }

    private func readHIDSensorsDetailed() -> [SensorInfo] {
        var hidSensors: [SensorInfo] = []
        
        typealias IOHIDEventSystemClientCreateType = @convention(c) (CFAllocator?) -> OpaquePointer?
        typealias IOHIDEventSystemClientSetMatchingType = @convention(c) (OpaquePointer, CFDictionary?) -> Void
        typealias IOHIDEventSystemClientCopyServicesType = @convention(c) (OpaquePointer) -> CFArray?
        typealias IOHIDServiceClientCopyEvent = @convention(c) (OpaquePointer, Int64, Int32, Int64) -> OpaquePointer?
        typealias IOHIDEventGetFloatValue = @convention(c) (OpaquePointer, UInt32) -> Double
        typealias IOHIDServiceClientCopyProperty = @convention(c) (OpaquePointer, CFString) -> CFTypeRef?

        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            print("[-] Error: No se pudo abrir IOKit.framework")
            return hidSensors
        }
        defer { dlclose(handle) }

        guard let createSym = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let setMatchingSym = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let copyServicesSym = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let copyEventSym = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let getFloatValueSym = dlsym(handle, "IOHIDEventGetFloatValue"),
              let copyPropSym = dlsym(handle, "IOHIDServiceClientCopyProperty") else {
            print("[-] Error: No se pudieron vincular símbolos IOHID")
            return hidSensors
        }

        let clientCreate = unsafeBitCast(createSym, to: IOHIDEventSystemClientCreateType.self)
        let clientSetMatching = unsafeBitCast(setMatchingSym, to: IOHIDEventSystemClientSetMatchingType.self)
        let clientCopyServices = unsafeBitCast(copyServicesSym, to: IOHIDEventSystemClientCopyServicesType.self)
        let serviceCopyEvent = unsafeBitCast(copyEventSym, to: IOHIDServiceClientCopyEvent.self)
        let eventGetFloatValue = unsafeBitCast(getFloatValueSym, to: IOHIDEventGetFloatValue.self)
        let serviceCopyProperty = unsafeBitCast(copyPropSym, to: IOHIDServiceClientCopyProperty.self)

        guard let client = clientCreate(kCFAllocatorDefault) else { return hidSensors }

        let matchings: [[String: Any]?] = [
            ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5],
            ["PrimaryUsagePage": 0xff00],
            nil
        ]

        for matchingDict in matchings {
            if let dict = matchingDict {
                clientSetMatching(client, dict as CFDictionary)
            } else {
                clientSetMatching(client, nil)
            }

            guard let services = clientCopyServices(client) else { continue }
            let count = CFArrayGetCount(services)
            if count == 0 { continue }

            for i in 0..<count {
                guard let serviceRaw = CFArrayGetValueAtIndex(services, i) else { continue }
                let service = OpaquePointer(serviceRaw)
                
                // Extraer metadatos de las propiedades de IOKit
                let productProp = serviceCopyProperty(service, "Product" as CFString) as? String
                let nameProp = serviceCopyProperty(service, "PrimaryUsageName" as CFString) as? String
                let zoneProp = serviceCopyProperty(service, "ThermalZone" as CFString) as? String
                let usagePageProp = serviceCopyProperty(service, "PrimaryUsagePage" as CFString) as? Int
                let usageProp = serviceCopyProperty(service, "PrimaryUsage" as CFString) as? Int
                
                let rawName = productProp ?? nameProp ?? "Sensor HID \(i + 1)"

                let kIOHIDEventTypeTemperature: Int64 = 15
                if let event = serviceCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0) {
                    let temp = eventGetFloatValue(event, 15 << 16)
                    if temp > 0 && temp < 130 {
                        // Clasificar el sensor
                        let category: SensorCategory
                        let explanation: String
                        
                        if rawName.contains("tdie") {
                            category = .socDie
                            explanation = "Sensor incrustado en el silicio del procesador (SoC M4). Mide núcleos de CPU (P-Core/E-Core), GPU o Neural Engine."
                        } else if rawName.contains("tdev") {
                            category = .pmuBoard
                            explanation = "Sensor periférico en la placa madre / circuito PMIC de administración de energía."
                        } else if rawName.contains("TB") || rawName.lowercased().contains("bat") {
                            category = .battery
                            explanation = "Sensor térmico situado en la batería o controlador de carga."
                        } else {
                            category = .unknown
                            explanation = "Sensor reportado por la interfaz IOHID ThermalZone de macOS."
                        }
                        
                        let info = SensorInfo(
                            id: "\(rawName)_\(i)",
                            rawKey: rawName,
                            value: temp,
                            source: .hid,
                            category: category,
                            thermalZone: zoneProp ?? "PMU Zone",
                            usagePage: usagePageProp ?? 0xFF00,
                            usage: usageProp ?? 5,
                            descriptionText: explanation
                        )
                        
                        // Evitar duplicados por nombre
                        if !hidSensors.contains(where: { $0.rawKey == rawName }) {
                            hidSensors.append(info)
                        }
                    }
                }
            }

            if !hidSensors.isEmpty {
                break
            }
        }

        return hidSensors
    }

    func getDetailedSensors() -> (sensors: [SensorInfo], connectionOk: Bool) {
        print("[SMC/HID] Iniciando escaneo detallado de metadatos...")
        var results: [SensorInfo] = []
        var connectionOk = false

        // 1. Escanear SMC tradicional
        if openConnection() {
            connectionOk = true
            for keyName in knownAppleSiliconKeys {
                if let temp = readTemperatureKey(keyName) {
                    let category: SensorCategory = keyName.hasPrefix("TB") ? .battery : .smcGlobal
                    let info = SensorInfo(
                        id: keyName,
                        rawKey: keyName,
                        value: temp,
                        source: .smc,
                        category: category,
                        thermalZone: "AppleSMC Subsystem",
                        usagePage: nil,
                        usage: nil,
                        descriptionText: "Lectura directa por clave de registro de firmware AppleSMC (\(keyName))."
                    )
                    results.append(info)
                }
            }
            closeConnection()
        }

        // 2. Escanear IOHID Sensors (Apple Silicon)
        let hidResults = readHIDSensorsDetailed()
        if !hidResults.isEmpty {
            connectionOk = true
            results.append(contentsOf: hidResults)
        }

        print("[SMC/HID] Escaneo completado. Total de sensores con metadatos: \(results.count)")
        return (results, connectionOk)
    }
}
