import Foundation

/// High-level service for reading fans through the SMC.
///
/// Exposes the full list of fans with all their metrics. Internally
/// uses a shared `SMCClient` and delegates RPM parsing to `FanDataParser`.
final class FansReader {
    private let client: SMCClient

    init(client: SMCClient = SMCClient()) {
        self.client = client
    }

    /// Returns the full list of installed fans with their metrics.
    /// - Returns: `[FanInfo]` with one element per fan detectado.
    func readAllFans() -> [FanInfo] {
        guard client.open() else { return [] }
        defer { client.close() }

        var fansList: [FanInfo] = []

        // 1. Get the total number of fans by reading the 'FNum' key.
        var fanCount = 0
        if let numData = client.readKeyData("FNum"), !numData.bytes.isEmpty {
            fanCount = Int(numData.bytes[0])
        }

        // 2. Fallback: if FNum returns 0, probe directly for the existence of F0Ac, F1Ac...
        if fanCount == 0 {
            for i in 0..<4 {
                if client.readKeyData("F\(i)Ac") != nil {
                    fanCount = i + 1
                } else {
                    break
                }
            }
        }

        AppLog.log("[FansReader] Physical fans detected: \(fanCount)")

        // 3. Iterate reading each fan's keys.
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
                name: fanCount == 1 ? "Main Fan" : "Fan \(i + 1)",
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
