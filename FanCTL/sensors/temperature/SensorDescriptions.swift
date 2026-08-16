import Foundation

/// Explicaciones en lenguaje humano para los sensores conocidos de Apple
/// Silicon (macOS los reporta por la interfaz IOHID ThermalZone con nombres
/// tipo `PMU tdie5`, `PMU2 tdev3`, etc.).
enum SensorDescriptions {
    /// Devuelve una explicación para un sensor según su clave cruda.
    static func description(for rawKey: String, category: SensorCategory) -> String {
        let key = rawKey.lowercased()

        // SoC die: núcleos de CPU/GPU/Neural Engine incrustados en el silicio
        if key.contains("tdie") {
            let zone = rawKey.hasPrefix("pmu2") ? "servicio térmico 2 del PMU" : "servicio térmico del PMU"
            return "Sensor incrustado en el silicio del procesador (SoC M4), reportado por el \(zone). Mide la temperatura de un bloque del chip: núcleos de CPU, GPU o Neural Engine. Es la lectura más útil para controlar el ventilador."
        }

        // tdev: periféricos de la placa / PMIC
        if key.contains("tdev") {
            return "Sensor térmico de un componente periférico de la placa base / circuito de gestión de energía (PMIC). No es la temperatura de la CPU, sino de reguladores o componentes cercanos al chip."
        }

        // tcal: calibración
        if key.contains("tcal") {
            return "Sensor de calibración térmica de la unidad de gestión de energía (PMU). Es una referencia de baja sensibilidad; no sube con la carga y NO es útil para controlar el ventilador."
        }

        // NAND / SSD
        if key.contains("nand") {
            return "Temperatura de la memoria flash NAND del SSD (memoria de almacenamiento). Sube con escrituras intensas o copias grandes de archivos."
        }

        switch category {
        case .socDie:
            return "Sensor incrustado en el silicio del procesador (SoC M4). Mide núcleos de CPU (P-Core/E-Core), GPU o Neural Engine."
        case .pmuBoard:
            return "Sensor periférico en la placa madre / circuito PMIC de administración de energía."
        case .powerManagement:
            return "Sensor de la unidad de gestión de energía (PMU). Hace referencia a la electrónica de alimentación del equipo."
        case .storage:
            return "Sensor térmico de la memoria flash NAND del SSD. Sube con escrituras intensas o copias grandes de archivos."
        case .battery:
            return "Sensor térmico situado en la batería o controlador de carga."
        case .smcGlobal:
            return "Lectura directa por clave de registro de firmware AppleSMC (\(rawKey))."
        case .unknown:
            return "Sensor reportado por la interfaz IOHID ThermalZone de macOS."
        }
    }

    /// Nombre corto y legible para mostrar en la interfaz.
    static func shortName(for rawKey: String) -> String {
        let key = rawKey.lowercased()
        if key.contains("tdie") {
            return "SoC / Procesador"
        }
        if key.contains("tdev") {
            return "Placa / PMIC"
        }
        if key.contains("tcal") {
            return "Gestión de energía"
        }
        if key.contains("nand") {
            return "SSD (NAND)"
        }
        return "Sensor"
    }
}
