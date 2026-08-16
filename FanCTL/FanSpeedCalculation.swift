import Foundation

/// Cálculo del objetivo de velocidad de un ventilador según la temperatura.
///
/// De los sensores seleccionados para el ventilador se toma la temperatura
/// máxima. Ese valor se normaliza contra el rango [minTemperature, maxTemperature]
/// (por debajo del mínimo → 0, por encima del máximo → 1) y ese factor se aplica
/// al rango de velocidades del ventilador (minRPM...maxRPM).
struct FanSpeedCalculation {
    /// Temperatura máxima medida entre los sensores seleccionados (°C).
    let maxSelectedTemperature: Double?
    /// Valor normalizado de la temperatura en [0, 1].
    let normalizedValue: Double
    /// Velocidad objetivo calculada en RPM.
    let targetRPM: Double?

    static func compute(fan: FanInfo, config: FanSettings, sensors: [SensorInfo]) -> FanSpeedCalculation {
        let selectedSensors = sensors.filter { config.selectedSensorKeys.contains($0.id) }
        let maxTemp = selectedSensors.map(\.value).max()

        guard let maxTemp else {
            return FanSpeedCalculation(maxSelectedTemperature: nil, normalizedValue: 0, targetRPM: nil)
        }

        // Normalizar la temperatura al rango configurado, recortando a [0, 1]
        let tempRange = config.maxTemperature - config.minTemperature
        var normalized = tempRange > 0 ? (maxTemp - config.minTemperature) / tempRange : 0
        normalized = min(1, max(0, normalized))

        // Aplicar el mismo factor al rango de velocidad del ventilador
        // (o al rango personalizado configurado por el usuario, si existe).
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
