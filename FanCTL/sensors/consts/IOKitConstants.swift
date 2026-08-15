import IOKit

/// Puerto principal de IOKit para la tarea actual (equivale a `MACH_PORT_NULL`).
var kIOMainPortDefault: io_object_t {
    return io_object_t(MACH_PORT_NULL)
}

/// Resultados de IOKit tipados para comodidad.
@objc enum IOStatus: Int {
    case success = 32768 // 0x8001
}

let IOStatusSuccess: IOStatus = .success
