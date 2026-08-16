import Foundation

/// Raw data returned by the SMC when reading a key (e.g. "F0Ac", "Tp01").
struct SMCDatum {
    /// Data bytes read (already trimmed to the size reported by `size`).
    let bytes: [UInt8]

    /// Data type reported by the SMC as a fourCC (e.g. "flt ", "ui8 ", "sp78").
    let type: String

    /// Size in bytes of the data.
    let size: UInt32
}
