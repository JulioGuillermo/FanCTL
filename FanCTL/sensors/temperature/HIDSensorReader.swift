import Foundation
import IOKit

/// Temperature sensor scanner exposed by the IOHID interface
/// (ThermalZone) of Apple Silicon Macs.
///
/// Dynamically links the `IOHIDEventSystemClient*` and
/// `IOHIDServiceClient*` symbols to query the HID thermal services.
final class HIDSensorReader {
    /// Returns the thermal sensor list reported by IOHID.
    func readSensors() -> [SensorInfo] {
        var hidSensors: [SensorInfo] = []

        typealias IOHIDEventSystemClientCreateType = @convention(c) (CFAllocator?) -> OpaquePointer?
        typealias IOHIDEventSystemClientSetMatchingType = @convention(c) (OpaquePointer, CFDictionary?) -> Void
        typealias IOHIDEventSystemClientCopyServicesType = @convention(c) (OpaquePointer) -> CFArray?
        typealias IOHIDServiceClientCopyEvent = @convention(c) (OpaquePointer, Int64, Int32, Int64) -> OpaquePointer?
        typealias IOHIDEventGetFloatValue = @convention(c) (OpaquePointer, UInt32) -> Double
        typealias IOHIDServiceClientCopyProperty = @convention(c) (OpaquePointer, CFString) -> CFTypeRef?

        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            AppLog.log("[HIDSensorReader] Error: could not open IOKit.framework")
            return hidSensors
        }
        defer { dlclose(handle) }

        guard let createSym = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let setMatchingSym = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let copyServicesSym = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let copyEventSym = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let getFloatValueSym = dlsym(handle, "IOHIDEventGetFloatValue"),
              let copyPropSym = dlsym(handle, "IOHIDServiceClientCopyProperty") else {
            AppLog.log("[HIDSensorReader] Error: could not link IOHID symbols")
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

                // Extract metadata from the IOKit properties
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
                        let lower = rawName.lowercased()

                        if lower.contains("tdie") {
                            category = .socDie
                        } else if lower.contains("tdev") {
                            category = .pmuBoard
                        } else if lower.contains("tcal") {
                            category = .powerManagement
                        } else if lower.contains("nand") {
                            category = .storage
                        } else if lower.contains("tb") || lower.contains("bat") {
                            category = .battery
                        } else {
                            category = .unknown
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
                            descriptionText: SensorDescriptions.description(for: rawName, category: category)
                        )

                        // Avoid duplicates by name
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
