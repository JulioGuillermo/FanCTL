import Foundation

/// Computation of a fan's target speed based on temperature.
///
/// Of the sensors selected for the fan, the maximum temperature is taken.
/// That value is normalized against the range [minTemperature, maxTemperature]
/// (below minimum → 0, above maximum → 1) and that factor is applied
/// to the fan's speed range (minRPM...maxRPM).
struct FanSpeedCalculation {
    /// Maximum temperature measured among the selected sensors (°C).
    let maxSelectedTemperature: Double?
    /// Temperature normalized to [0, 1].
    let normalizedValue: Double
    /// Computed target speed in RPM.
    let targetRPM: Double?

    static func compute(fan: FanInfo, config: FanSettings, sensors: [SensorInfo]) -> FanSpeedCalculation {
        let selectedSensors = sensors.filter { config.selectedSensorKeys.contains($0.id) && $0.isTemperature }
        let maxTemp = selectedSensors.map(\.value).max()

        guard let maxTemp else {
            return FanSpeedCalculation(maxSelectedTemperature: nil, normalizedValue: 0, targetRPM: nil)
        }

        // Normalize the temperature to the configured range, clamping to [0, 1]
        let tempRange = config.maxTemperature - config.minTemperature
        var normalized = tempRange > 0 ? (maxTemp - config.minTemperature) / tempRange : 0
        normalized = min(1, max(0, normalized))

        // Apply the same factor to the fan's speed range
        // (or to the user-configured custom range, if any).
        let lowRPM = config.effectiveMinRPM(fanMinRPM: fan.minRPM)
        let highRPM = config.effectiveMaxRPM(fanMaxRPM: fan.maxRPM)
        let speedRange = max(highRPM - lowRPM, 0)
        var targetRPM = lowRPM + normalized * speedRange
        targetRPM = min(max(targetRPM, fan.minRPM), fan.maxRPM)

        return FanSpeedCalculation(
            maxSelectedTemperature: maxTemp,
            normalizedValue: normalized,
            targetRPM: targetRPM
        )
    }
}
