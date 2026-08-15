import Foundation

/// Datos crudos devueltos por el SMC al leer una clave (ej. "F0Ac", "Tp01").
struct SMCDatum {
    /// Bytes de datos leídos (ya recortados al tamaño reportado por `size`).
    let bytes: [UInt8]

    /// Tipo de dato reportado por el SMC como fourCC (ej. "flt ", "ui8 ", "sp78").
    let type: String

    /// Tamaño en bytes de los datos.
    let size: UInt32
}
