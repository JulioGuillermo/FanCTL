import Foundation

/// Complete snapshot of the machine's thermal and fan state.
struct SensorsSnapshot {
    /// All detected temperature sensors (SMC + HID).
    let sensors: [SensorInfo]

    /// Complete fan list with its metrics.
    let fans: [FanInfo]

    /// Indicates whether at least one source (SMC or HID) responded correctly.
    let connectionOk: Bool
}
