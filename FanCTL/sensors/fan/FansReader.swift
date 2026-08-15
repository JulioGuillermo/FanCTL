import Foundation

/// Servicio de alto nivel para lectura de ventiladores a través del SMC.
///
/// Expone la lista completa de ventiladores con todas sus métricas. Internamente
/// usa un `SMCClient` compartido y delega el parseo de RPM en `FanDataParser`.
final class FansReader {
    private let client: SMCClient

    init(client: SMCClient = SMCClient()) {
        self.client = client
    }

    /// Devuelve la lista completa de ventiladores instalados con sus métricas.
    /// - Returns: `[FanInfo]` con un elemento por ventilador detectado.
    func readAllFans() -> [FanInfo] {
        guard client.open() else { return [] }
        defer { client.close() }

        var fansList: [FanInfo] = []

        // 1. Obtener la cantidad total de ventiladores leyendo la clave 'FNum'.
        var fanCount = 0
        if let numData = client.readKeyData("FNum"), !numData.bytes.isEmpty {
            fanCount = Int(numData.bytes[0])
        }

        // 2. Fallback: si FNum devuelve 0, sondear directamente la existencia de F0Ac, F1Ac...
        if fanCount == 0 {
            for i in 0..<4 {
                if client.readKeyData("F\(i)Ac") != nil {
                    fanCount = i + 1
                } else {
                    break
                }
            }
        }

        AppLog.log("[FansReader] Ventiladores físicos detectados: \(fanCount)")

        // 3. Iterar leyendo las claves de cada ventilador.
        for i in 0..<fanCount {
            let actualKey = "F\(i)Ac"
            let minKey    = "F\(i)Mn"
            let maxKey    = "F\(i)Mx"
            let targetKey = "F\(i)Tg"

            let actual = readFanValue(actualKey) ?? 0.0
            let minVal = readFanValue(minKey) ?? 1200.0
            let maxVal = readFanValue(maxKey) ?? 5000.0
            let target = readFanValue(targetKey)

            fansList.append(FanInfo(
                id: i,
                name: fanCount == 1 ? "Ventilador Principal" : "Ventilador \(i + 1)",
                currentRPM: actual,
                minRPM: minVal,
                maxRPM: maxVal,
                targetRPM: target,
                mode: .automatic
            ))
        }

        return fansList
    }

    private func readFanValue(_ key: String) -> Double? {
        guard let datum = client.readKeyData(key) else { return nil }
        return FanDataParser.rpm(from: datum)
    }
}
