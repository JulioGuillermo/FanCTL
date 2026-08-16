import Foundation

/// Scanner of SMC sensors reading directly by AppleSMC register key.
///
/// The key set is model-specific on Apple Silicon: each generation uses a
/// different layout. The table below was verified on an M4 Mac mini by dumping
/// every responding key (`smc list` style) and contains the keys that actually
/// return data on this machine:
///
/// - `Tp*`: CPU performance cores (P-cores)
/// - `Te*`: CPU efficiency cores (E-cores)
/// - `Tg*`: GPU clusters
/// - `Tm*`: unified memory (RAM)
/// - `Ts*`, `Ta*`, `Tz*`, `TfC*`: generic SoC / ambient thermal sensors
/// - `TCM*`, `TH0*`, `TPD*`, `TRD*`, etc.: power delivery and regulator thermals
/// - `P*`: power consumption in watts (PSTR = total platform, PHPC = CPU, ...)
/// - `V*`: rail voltages in volts (VD0R = DC-in, VRTC, Vsw*, ...)
///
/// Power and voltage keys are reported by the power delivery controller and are
/// useful to see what the machine is doing, but they are NOT temperatures.
final class TemperatureSMCReader {
    private let client: SMCClient

    private struct KeySpec {
        let key: String
        let name: String
        let category: SensorCategory
        let unit: String
    }

    private let specs: [KeySpec] = TemperatureSMCReader.buildSpecs()

    init(client: SMCClient = SMCClient()) {
        self.client = client
    }

    /// Reads all known keys and returns the sensors found.
    /// - Returns: tuple with the sensor list and whether the SMC connection worked.
    func readSensors() -> (sensors: [SensorInfo], connectionOk: Bool) {
        guard client.open() else { return ([], false) }
        defer { client.close() }

        var results: [SensorInfo] = []

        for spec in specs {
            guard let datum = client.readKeyData(spec.key),
                  let value = TemperatureDataParser.value(from: datum, unit: spec.unit) else { continue }

            // Dead rails report exactly 0.00: skip them to reduce noise.
            if spec.unit != "°C" && value == 0 { continue }

            results.append(SensorInfo(
                id: spec.key,
                rawKey: spec.key,
                value: value,
                source: .smc,
                category: spec.category,
                thermalZone: "AppleSMC Subsystem",
                usagePage: nil,
                usage: nil,
                descriptionText: Self.description(for: spec.key, category: spec.category, name: spec.name),
                unit: spec.unit
            ))
        }

        return (results, true)
    }

    private static func description(for key: String, category: SensorCategory, name: String) -> String {
        switch category {
        case .gpu:
            return "GPU temperature cluster exposed by the AppleSMC register key (\(key)). Reads the silicon block where the graphics cores live."
        case .memory:
            return "Unified memory (RAM) temperature exposed by the AppleSMC register key (\(key)). Rises with memory-heavy workloads."
        case .socDie:
            return "SoC die temperature exposed by the AppleSMC register key (\(key)). Thermal sensor of a CPU core block (P-core/E-core) or SoC zone."
        case .powerManagement:
            return "Power delivery thermal sensor exposed by the AppleSMC register key (\(key)). Measures regulators or power delivery components."
        case .power:
            return "Power consumption in watts exposed by the AppleSMC register key (\(key)). Reported by the power delivery controller."
        case .voltage:
            return "Voltage of a power rail in volts exposed by the AppleSMC register key (\(key)). Reported by the power delivery controller."
        case .pmuBoard:
            return "Peripheral sensor on the motherboard, exposed by the AppleSMC register key (\(key))."
        default:
            return "Direct reading through the AppleSMC register key (\(key))."
        }
    }

    // MARK: - Key table (verified on M4)

    private static func buildSpecs() -> [KeySpec] {
        var list: [KeySpec] = []

        func family(_ prefix: String, _ suffixes: [String], _ name: String,
                    _ category: SensorCategory, _ unit: String = "°C") {
            for (i, suffix) in suffixes.enumerated() {
                list.append(KeySpec(key: prefix + suffix, name: "\(name) \(i + 1)",
                                    category: category, unit: unit))
            }
        }

        func single(_ key: String, _ name: String, _ category: SensorCategory,
                    _ unit: String = "°C") {
            list.append(KeySpec(key: key, name: name, category: category, unit: unit))
        }

        // CPU performance cores (P-cores)
        family("Tp", ["00","01","02","04","05","06","08","09","0A","0C","0D","0E",
                      "0U","0V","0W","0X","0Y","0Z","0a","0b","0c","0d","0e","0f",
                      "1A","1B","1C","1E","1F","1G","1Q","1R","1S",
                      "3O","3P","3S","3T","3W","3X"], "CPU P-core", .socDie)

        // CPU efficiency cores (E-cores)
        family("Te", ["04","05","06","08","09","0A","0G","0H","0I",
                      "0R","0S","0T","0U","0V","0W","0X"], "CPU E-core", .socDie)

        // GPU clusters
        family("Tg", ["0C","0D","0G","0H","0K","0L","0O","0P","0U","0V","0X","0Y",
                      "0d","0e","0j","0k","0m","0n"], "GPU cluster", .gpu)

        // Unified memory (RAM)
        family("Tm", ["0p","1p","2p"], "Memory", .memory)

        // Generic SoC sensors
        family("Ts", ["00","01","02","04","05","06","08","09","0A","0C","0D","0E",
                      "0G","0H","0I","0K","0L","0M","0O","0Q","0R","0S","0T","0U",
                      "0V","0W","0X","0h","0i"], "SoC sensor", .socDie)

        // Ambient sensors
        family("Ta", ["00","01","04","05","08","09","0K","0L","0O","0P","0R","0S","0p"],
               "Ambient", .unknown)

        // Thermal zones (currently report 0 on this model)
        family("Tz", ["11","12","13","14","15","16","17","18","1j"],
               "Thermal zone", .unknown)

        // SoC cluster sensors
        family("TfC", ["0","1"], "SoC cluster", .socDie)

        // Heatsink / chassis thermal sensors
        family("TH0", ["a","b","p","x"], "Heatsink", .smcGlobal)
        single("TIED", "SoC die (extra)", .socDie)
        single("TMVR", "Memory VR sensor", .smcGlobal)
        single("TSCD", "SoC control die", .socDie)
        single("TT0P", "SMC thermal sensor", .smcGlobal)
        single("TUVR", "Voltage regulator sensor", .smcGlobal)
        single("TVA0", "SMC thermal sensor", .smcGlobal)
        single("TVD0", "SMC thermal sensor", .smcGlobal)
        single("TVS0", "SMC thermal sensor", .smcGlobal)
        single("TVS1", "SMC thermal sensor", .smcGlobal)
        single("TVV0", "SMC thermal sensor", .smcGlobal)
        single("TW0P", "SMC thermal sensor", .smcGlobal)
        single("TCMb", "SMC thermal sensor", .smcGlobal)
        single("TCMz", "SMC thermal sensor", .smcGlobal)

        // Power delivery thermals
        family("TPD", ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","X"],
               "Power delivery", .powerManagement)
        single("TPSD", "Power supply sensor", .powerManagement)
        single("TPSP", "Power supply sensor", .powerManagement)
        family("TRD", ["0","1","2","3","4","5","6","7","X"],
               "Regulator diode", .powerManagement)

        // Power consumption (watts)
        single("PSTR", "Total platform power", .power, "W")
        single("PD0R", "DC-in power (input)", .power, "W")
        single("PDTR", "DC-in power (input)", .power, "W")
        single("PHPC", "CPU package power", .power, "W")
        single("PHPS", "CPU package power (secondary)", .power, "W")
        single("PHPM", "PMIC power", .power, "W")
        single("PHPB", "Power bus power", .power, "W")
        single("PH2R", "Power rail (3.3V)", .power, "W")
        single("PH3R", "Power rail (5V)", .power, "W")
        single("PO5R", "Power rail (5V)", .power, "W")
        single("PMVC", "PMIC power", .power, "W")
        single("PPMR", "Memory power rail", .power, "W")
        single("PPSR", "Power supply rail", .power, "W")
        single("PUFC", "USB-C power (front)", .power, "W")
        single("PURC", "USB-C power (rear)", .power, "W")
        single("PUTC", "USB-C power (total)", .power, "W")
        single("PZC0", "Power zone C0", .power, "W")
        single("PZC1", "Power zone C1", .power, "W")
        single("PZCB", "Power zone CB", .power, "W")
        single("PZCU", "Power zone CU", .power, "W")
        single("PZD1", "Power zone D1", .power, "W")
        single("Pb0f", "Power rail (battery bus)", .power, "W")
        family("PP", ["0b","1b","1l","2b","2l","3b","3l","4b","5l","7b","7l","8l",
                      "9b","9l","al","bb","bl","cl","db","dl","eb","el","fl","kl"],
               "Power rail", .power, "W")
        family("PR", ["4l","8b","9l","al","cb","fb"],
               "Power rail", .power, "W")

        // Voltages (volts)
        single("VD0R", "DC-in voltage (input)", .voltage, "V")
        single("VDMA", "Memory voltage", .voltage, "V")
        single("VDMM", "Memory voltage", .voltage, "V")
        single("VMVC", "PMIC voltage", .voltage, "V")
        single("VRTC", "RTC voltage", .voltage, "V")
        single("Vldo", "LDO rail voltage", .voltage, "V")
        single("Vsw1", "Switcher rail voltage", .voltage, "V")
        single("Vsw2", "Switcher rail voltage", .voltage, "V")
        single("Vsw3", "Switcher rail voltage", .voltage, "V")
        single("Vb0f", "Power bus voltage", .voltage, "V")
        single("Vb1f", "Power bus voltage", .voltage, "V")
        single("VPOI", "Voltage rail", .voltage, "V")
        single("VPOi", "Voltage rail", .voltage, "V")
        family("VP", ["0b","1b","1l","2b","2l","3b","3l","4b","5l","7b","7l","8l",
                      "9b","9l","al","bb","bl","cl","db","dl","eb","el","fl","kl"],
               "Voltage rail", .voltage, "V")
        family("VR", ["4l","8b","9l","al","cb","fb"],
               "Voltage rail", .voltage, "V")

        return list
    }
}
