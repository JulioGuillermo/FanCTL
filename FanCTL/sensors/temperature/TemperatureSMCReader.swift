import Foundation

/// Temperature sensor scanner reading directly by SMC key.
///
/// Iterates over a set of known keys of Apple Silicon Macs and
/// returns the sensors found with their category and metadata.
final class TemperatureSMCReader {
    private let client: SMCClient

    /// Typical temperature keys on Apple Silicon Macs.
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

    /// Reads all known keys and returns the sensors found.
    /// - Returns: tuple with the sensor list and whether the SMC connection worked.
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
                descriptionText: "Direct reading by AppleSMC firmware register key (\(keyName))."
            ))
        }

        return (results, true)
    }
}
