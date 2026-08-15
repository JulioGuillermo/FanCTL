import Foundation
internal import Combine

/// Controlador de selección de sensores de temperatura.
///
/// Mantiene el estado de qué sensores están seleccionados (por defecto todos)
/// y expone la temperatura máxima entre los seleccionados, útil para alertas
/// o cálculos agregados.
final class SensorSelectionController: ObservableObject {
    @Published private(set) var sensors: [SensorInfo] = []
    @Published private(set) var selectedKeys: Set<String> = []

    init(sensors: [SensorInfo] = []) {
        updateSensors(sensors)
    }

    /// Actualiza la lista de sensores tras un refresco, conservando la selección
    /// existente y seleccionando por defecto los sensores nuevos.
    func updateSensors(_ newSensors: [SensorInfo]) {
        let newIds = Set(newSensors.map(\.id))
        selectedKeys = newIds.union(selectedKeys)
        sensors = newSensors
    }

    func isSelected(_ sensor: SensorInfo) -> Bool {
        selectedKeys.contains(sensor.id)
    }

    func toggle(_ sensor: SensorInfo) {
        if selectedKeys.contains(sensor.id) {
            selectedKeys.remove(sensor.id)
        } else {
            selectedKeys.insert(sensor.id)
        }
    }

    func selectAll() {
        selectedKeys = Set(sensors.map(\.id))
    }

    func selectNone() {
        selectedKeys = []
    }

    /// Cantidad de sensores actualmente seleccionados.
    var selectedCount: Int {
        sensors.filter { selectedKeys.contains($0.id) }.count
    }

    /// Sensores actualmente seleccionados.
    var selectedSensors: [SensorInfo] {
        sensors.filter { selectedKeys.contains($0.id) }
    }

    /// Máxima temperatura entre los sensores seleccionados, o `nil` si no hay ninguno.
    var maxTemperature: Double? {
        selectedSensors.map(\.value).max()
    }
}
