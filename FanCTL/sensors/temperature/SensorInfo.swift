import Foundation

/// Estructura completa de información y metadatos de un sensor térmico.
struct SensorInfo: Identifiable, Hashable {
    let id: String              // Identificador único (ej. "PMU2 tdie1")
    let rawKey: String          // Nombre o clave cruda en IOKit/SMC
    let value: Double           // Lectura en grados Celsius
    let source: SensorSource    // Origen de la lectura (SMC o HID)
    let category: SensorCategory// Categoría asignada
    let thermalZone: String?    // Zona térmica reportada por IOKit (si existe)
    let usagePage: Int?         // HID Usage Page (ej. 0xFF00)
    let usage: Int?             // HID Usage (ej. 5 para Temperatura)
    let descriptionText: String // Explicación técnica del sensor
}
