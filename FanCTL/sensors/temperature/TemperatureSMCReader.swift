import Foundation

/// Escáner de sensores de temperatura leídos directamente por clave SMC.
///
/// Recorre un conjunto de claves conocidas de los Macs Apple Silicon y
/// devuelve los sensores encontrados con su categoría y metadatos.
final class TemperatureSMCReader {
    private let client: SMCClient

    /// Claves típicas de temperatura en Macs Apple Silicon.
    private let knownKeys: [String] = [
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0T", "Tp0P",
        "TG0b", "TG0d", "TG0P",
        "TB0T", "TB1T", "TB2T",
        "TM0P", "TM0S", "Th0H", "Th1H",
        "F0Ac", "F1Ac"
    ]

    init(client: SMCClient = SMCClient()) {
        self.client = client
    }

    /// Lee todas las claves conocidas y devuelve los sensores encontrados.
    /// - Returns: Tupla con la lista de sensores y si la conexión SMC funcionó.
    func readSensors() -> (sensors: [SensorInfo], connectionOk: Bool) {
        guard client.open() else { return ([], false) }
        defer { client.close() }

        var results: [SensorInfo] = []

        for keyName in knownKeys {
            guard let datum = client.readKeyData(keyName),
                  let temp = TemperatureDataParser.temperature(from: datum) else { continue }

            let category: SensorCategory = keyName.hasPrefix("TB") ? .battery : .smcGlobal
            results.append(SensorInfo(
                id: keyName,
                rawKey: keyName,
                value: temp,
                source: .smc,
                category: category,
                thermalZone: "AppleSMC Subsystem",
                usagePage: nil,
                usage: nil,
                descriptionText: "Lectura directa por clave de registro de firmware AppleSMC (\(keyName))."
            ))
        }

        return (results, true)
    }
}
