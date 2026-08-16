import Foundation
internal import Combine

/// Hardware monitor read by the app, shared between the main UI and
/// the menu bar indicator.
final class HardwareMonitor: ObservableObject {
    @Published private(set) var maxTemperature: Double?
    @Published private(set) var fanSpeeds: [Int: Double] = [:]
    @Published private(set) var fanCount = 0

    func update(sensors: [SensorInfo], fans: [FanInfo], maxTempSensorKey: String?) {
        if let key = maxTempSensorKey, let chosen = sensors.first(where: { $0.id == key }) {
            maxTemperature = chosen.value
        } else {
            maxTemperature = sensors.map(\.value).max()
        }
        fanSpeeds = Dictionary(uniqueKeysWithValues: fans.map { ($0.id, $0.currentRPM) })
        fanCount = fans.count
    }
}
