import Foundation
internal import Combine

/// Hardware monitor read by the app, shared between the main UI and
/// the menu bar indicator.
final class HardwareMonitor: ObservableObject {
    @Published private(set) var maxTemperature: Double?
    @Published private(set) var fanSpeeds: [Int: Double] = [:]
    @Published private(set) var fanPercentages: [Int: Double] = [:]
    @Published private(set) var fanCount = 0

    func update(sensors: [SensorInfo], fans: [FanInfo], maxTempSensorKeys: [String]) {
        let pool = maxTempSensorKeys.isEmpty
            ? sensors.filter(\.isTemperature)
            : sensors.filter { maxTempSensorKeys.contains($0.id) && $0.isTemperature }
        maxTemperature = pool.map(\.value).max()
        fanSpeeds = Dictionary(uniqueKeysWithValues: fans.map { ($0.id, $0.currentRPM) })
        fanPercentages = Dictionary(uniqueKeysWithValues: fans.map { ($0.id, $0.percentage) })
        fanCount = fans.count
    }
}
