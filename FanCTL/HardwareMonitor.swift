import Foundation
internal import Combine

/// Monitor del hardware leído por la app, compartido entre la UI principal y
/// el indicador de la barra de menú.
final class HardwareMonitor: ObservableObject {
    @Published private(set) var maxTemperature: Double?
    @Published private(set) var fanSpeeds: [Int: Double] = [:]
    @Published private(set) var fanCount = 0

    func update(sensors: [SensorInfo], fans: [FanInfo]) {
        maxTemperature = sensors.map(\.value).max()
        fanSpeeds = Dictionary(uniqueKeysWithValues: fans.map { ($0.id, $0.currentRPM) })
        fanCount = fans.count
    }
}
