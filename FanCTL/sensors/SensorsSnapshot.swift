import Foundation

/// Snapshot completo del estado térmico y de ventilación del equipo.
struct SensorsSnapshot {
    /// Todos los sensores de temperatura detectados (SMC + HID).
    let sensors: [SensorInfo]

    /// Lista completa de ventiladores con sus métricas.
    let fans: [FanInfo]

    /// Indica si al menos un origen (SMC o HID) respondió correctamente.
    let connectionOk: Bool
}
