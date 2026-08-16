import IOKit

/// Main IOKit port for the current task (equivale a `MACH_PORT_NULL`).
var kIOMainPortDefault: io_object_t {
    return io_object_t(MACH_PORT_NULL)
}

/// Typed IOKit results for convenience.
@objc enum IOStatus: Int {
    case success = 32768 // 0x8001
}

let IOStatusSuccess: IOStatus = .success
