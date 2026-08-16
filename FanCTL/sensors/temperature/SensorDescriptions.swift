import Foundation

/// Human-readable explanations for known Apple Silicon sensors (macOS reports
/// them through the IOHID ThermalZone interface with names like
/// `PMU tdie5`, `PMU2 tdev3`, etc.).
enum SensorDescriptions {
    /// Returns an explanation for a sensor based on its raw key.
    static func description(for rawKey: String, category: SensorCategory) -> String {
        let key = rawKey.lowercased()

        // SoC die: CPU/GPU/Neural Engine cores embedded in the silicon
        if key.contains("tdie") {
            let zone = rawKey.hasPrefix("pmu2") ? "PMU thermal service 2" : "PMU thermal service"
            return "Sensor embedded in the processor silicon (SoC M4), reported by the \(zone). Measures the temperature of a chip block: CPU cores, GPU or Neural Engine. This is the most useful reading for fan control."
        }

        // tdev: board peripherals / PMIC
        if key.contains("tdev") {
            return "Thermal sensor of a peripheral component on the motherboard / power management circuit (PMIC). Not the CPU temperature, but regulators or components near the chip."
        }

        // tcal: calibration
        if key.contains("tcal") {
            return "Thermal calibration sensor of the power management unit (PMU). It is a low-sensitivity reference; it does not rise with load and is NOT useful for fan control."
        }

        // NAND / SSD
        if key.contains("nand") {
            return "Temperature of the SSD NAND flash memory (storage). Rises with heavy writes or large file copies."
        }

        switch category {
        case .socDie:
            return "Sensor embedded in the processor silicon (SoC M4). Measures CPU cores (P-Core/E-Core), GPU or Neural Engine."
        case .gpu:
            return "GPU temperature sensor of the Apple Silicon SoC. Rises with graphics load (Metal/OpenCL) or heavy display work."
        case .memory:
            return "Temperature of the unified memory (RAM) soldered to the SoC. Rises with memory-heavy workloads."
        case .pmuBoard:
            return "Peripheral sensor on the motherboard / PMIC power management circuit."
        case .powerManagement:
            return "Sensor of the power management unit (PMU). Refers to the power delivery electronics of the machine."
        case .storage:
            return "Thermal sensor of the SSD NAND flash memory. Rises with heavy writes or large file copies."
        case .battery:
            return "Thermal sensor on the battery or charge controller."
        case .smcGlobal:
            return "Direct reading through the AppleSMC firmware register key (\(rawKey))."
        case .power:
            return "Power consumption (watts) measured by the power delivery controller and exposed by the AppleSMC register key (\(rawKey))."
        case .voltage:
            return "Voltage (volts) of a power rail measured by the power delivery controller and exposed by the AppleSMC register key (\(rawKey))."
        case .unknown:
            return "Sensor reported by the macOS IOHID ThermalZone interface."
        }
    }

    /// Short readable name to show in the interface.
    static func shortName(for rawKey: String) -> String {
        let key = rawKey.lowercased()
        if key.contains("tdie") {
            return "SoC / Processor"
        }
        if key.contains("tdev") {
            return "Board / PMIC"
        }
        if key.contains("tcal") {
            return "Power management"
        }
        if key.contains("nand") {
            return "SSD (NAND)"
        }
        if key.hasPrefix("tp") {
            return "CPU P-core"
        }
        if key.hasPrefix("te") {
            return "CPU E-core"
        }
        if key.hasPrefix("tg") {
            return "GPU"
        }
        if key.hasPrefix("tm") {
            return "Memory"
        }
        if key.hasPrefix("ts") {
            return "SoC"
        }
        if key.hasPrefix("ta") {
            return "Ambient"
        }
        if key.hasPrefix("tz") {
            return "Thermal zone"
        }
        if key.hasPrefix("tfc") {
            return "SoC cluster"
        }
        if key.hasPrefix("th0") {
            return "Heatsink"
        }
        if key.hasPrefix("tpd") || key.hasPrefix("tps") {
            return "Power delivery"
        }
        if key.hasPrefix("trd") {
            return "Regulator"
        }
        if key.hasPrefix("pstr") || key.hasPrefix("pd0r") || key.hasPrefix("pdtr") {
            return "Platform power"
        }
        if key.hasPrefix("ph") {
            return "CPU / PMIC power"
        }
        if key.hasPrefix("pp") || key.hasPrefix("pr") || key.hasPrefix("pz") || key.hasPrefix("pb") {
            return "Power rail"
        }
        if key.hasPrefix("vdr") || key.hasPrefix("vd") {
            return "DC-in voltage"
        }
        if key.hasPrefix("vp") || key.hasPrefix("vr") || key.hasPrefix("vsw")
            || key.hasPrefix("vldo") || key.hasPrefix("vb") || key.hasPrefix("vm") {
            return "Voltage rail"
        }
        return "Sensor"
    }
}
