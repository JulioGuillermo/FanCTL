import Foundation
import IOKit

/// Escáner de sensores de temperatura expuestos por la interfaz IOHID
/// (ThermalZone) de los Macs Apple Silicon.
///
/// Enlaza dinámicamente los símbolos de `IOHIDEventSystemClient*` y
/// `IOHIDServiceClient*` para consultar los servicios térmicos HID.
final class HIDSensorReader {
    /// Devuelve la lista de sensores térmicos reportados por IOHID.
    func readSensors() -> [SensorInfo] {
        var hidSensors: [SensorInfo] = []

        typealias IOHIDEventSystemClientCreateType = @convention(c) (CFAllocator?) -> OpaquePointer?
        typealias IOHIDEventSystemClientSetMatchingType = @convention(c) (OpaquePointer, CFDictionary?) -> Void
        typealias IOHIDEventSystemClientCopyServicesType = @convention(c) (OpaquePointer) -> CFArray?
        typealias IOHIDServiceClientCopyEvent = @convention(c) (OpaquePointer, Int64, Int32, Int64) -> OpaquePointer?
        typealias IOHIDEventGetFloatValue = @convention(c) (OpaquePointer, UInt32) -> Double
        typealias IOHIDServiceClientCopyProperty = @convention(c) (OpaquePointer, CFString) -> CFTypeRef?

        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            AppLog.log("[HIDSensorReader] Error: No se pudo abrir IOKit.framework")
            return hidSensors
        }
        defer { dlclose(handle) }

        guard let createSym = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let setMatchingSym = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let copyServicesSym = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let copyEventSym = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let getFloatValueSym = dlsym(handle, "IOHIDEventGetFloatValue"),
              let copyPropSym = dlsym(handle, "IOHIDServiceClientCopyProperty") else {
            AppLog.log("[HIDSensorReader] Error: No se pudieron vincular símbolos IOHID")
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
}
