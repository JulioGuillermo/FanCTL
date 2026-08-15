import Foundation

/// Punto de entrada unificado de lectura del hardware.
///
/// Coordina los lectores especializados y devuelve en una sola llamada toda la
/// información del equipo: sensores de temperatura (SMC e IOHID) y ventiladores.
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

    /// Lee toda la información disponible del equipo en una sola llamada.
    /// - Returns: `SensorsSnapshot` con sensores y ventiladores.
    func readAll() -> SensorsSnapshot {
        AppLog.log("[SensorsReader] Escaneo iniciado...")

        let smcResult = temperatureReader.readSensors()
        let hidSensors = hidReader.readSensors()
        let fans = fansReader.readAllFans()

        var allSensors = smcResult.sensors
        allSensors.append(contentsOf: hidSensors)

        let connectionOk = smcResult.connectionOk || !hidSensors.isEmpty
        AppLog.log("[SensorsReader] Sensores: \(allSensors.count) (SMC \(smcResult.sensors.count) + HID \(hidSensors.count)), Ventiladores: \(fans.count)")

        return SensorsSnapshot(sensors: allSensors, fans: fans, connectionOk: connectionOk)
    }
}
