import Foundation

/// Unified hardware read entry point.
///
/// Coordinates the specialized readers and returns in a single call all the
/// machine information: temperature sensors (SMC and IOHID) and fans.
final class SensorsReader {
    private let temperatureReader: TemperatureSMCReader
    private let hidReader: HIDSensorReader
    private let fansReader: FansReader

    init(temperatureReader: TemperatureSMCReader = TemperatureSMCReader(),
         hidReader: HIDSensorReader = HIDSensorReader(),
         fansReader: FansReader = FansReader()) {
        self.temperatureReader = temperatureReader
        self.hidReader = hidReader
        self.fansReader = fansReader
    }

    /// Reads all available machine information in a single call.
    /// - Returns: `SensorsSnapshot` with sensors and fans.
    func readAll() -> SensorsSnapshot {
        AppLog.log("[SensorsReader] Scan started...")

        let smcResult = temperatureReader.readSensors()
        let hidSensors = hidReader.readSensors()
        let fans = fansReader.readAllFans()

        var allSensors = smcResult.sensors
        allSensors.append(contentsOf: hidSensors)

        let connectionOk = smcResult.connectionOk || !hidSensors.isEmpty
        AppLog.log("[SensorsReader] Sensors: \(allSensors.count) (SMC \(smcResult.sensors.count) + HID \(hidSensors.count)), Fans: \(fans.count)")

        return SensorsSnapshot(sensors: allSensors, fans: fans, connectionOk: connectionOk)
    }
}
