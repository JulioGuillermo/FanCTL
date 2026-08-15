import SwiftUI

/// Estructura de modelo con todas las métricas de un ventilador.
struct FanInfo: Identifiable, Hashable, Codable {
    let id: Int               // Índice del ventilador (0, 1, 2...)
    let name: String          // Nombre legible (ej. "Ventilador Principal")
    let currentRPM: Double    // Velocidad actual medida en RPM
    let minRPM: Double        // Velocidad mínima permitida por el firmware
    let maxRPM: Double        // Velocidad máxima permitida por el firmware
    let targetRPM: Double?    // Velocidad objetivo configurada por macOS
    let mode: FanMode         // Modo actual de funcionamiento

    /// Porcentaje relativo de velocidad actual respecto al rango (0.0 a 1.0)
    var percentage: Double {
        let totalRange = max(1.0, maxRPM - minRPM)
        let currentProgress = (currentRPM - minRPM) / totalRange
        return min(1.0, max(0.0, currentProgress))
    }

    /// Porcentaje formateado para visualización (0 - 100%)
    var percentageString: String {
        return String(format: "%.0f%%", percentage * 100.0)
    }

    /// Estado térmico visual sugerido según las RPMs
    var statusColor: Color {
        if currentRPM <= minRPM + 200 {
            return .blue      // En reposo / silencioso
        } else if currentRPM < (maxRPM * 0.75) {
            return .orange    // Carga moderada
        } else {
            return .red       // Carga alta / máximo rendimiento
        }
    }
}
