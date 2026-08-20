//
//  FanSettings.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 20/08/2026.
//

public struct FanSettings: Codable, Equatable, Identifiable {
    public var id: Int
    var name: String
    /// Control mode selected by the user.
    var mode: FanMode
    /// Maximum temperature (°C) to maintain on the selected sensors.
    var maxTemperature: Double
    /// Minimum temperature (°C) to maintain on the selected sensors.
    var minTemperature: Double
    /// IDs of the sensors that control this fan.
    var selectedSensorKeys: [String]
    /// Fixed speed in RPM for manual mode manual.
    var manualRPM: Double
    /// Custom lower limit (RPM); `nil` = the fan's real range.
    var minRPM: Double?
    /// Custom upper limit (RPM); `nil` = the fan's real range.
    var maxRPM: Double?
    /// Smoothing filter enabled; blends the calculated speed with the previous one.
    var filterEnabled: Bool
    /// Smoothing factor 0...1: 1 = unfiltered, 0 = stays fixed at the previous speed.
    var filterFactor: Double

    init(
        id: Int,
        name: String,
        mode: FanMode = .automatic,
        maxTemperature: Double = 90,
        minTemperature: Double = 30,
        selectedSensorKeys: [String] = [],
        manualRPM: Double = 1500,
        minRPM: Double? = nil,
        maxRPM: Double? = nil,
        filterEnabled: Bool = false,
        filterFactor: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.maxTemperature = maxTemperature
        self.minTemperature = minTemperature
        self.selectedSensorKeys = selectedSensorKeys
        self.manualRPM = manualRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.filterEnabled = filterEnabled
        self.filterFactor = filterFactor
    }

    enum CodingKeys: String, CodingKey {
        case id, name, mode, maxTemperature, minTemperature, selectedSensorKeys,
            manualRPM, minRPM, maxRPM, filterEnabled, filterFactor
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        mode = try c.decode(FanMode.self, forKey: .mode)
        maxTemperature =
            try c.decodeIfPresent(Double.self, forKey: .maxTemperature) ?? 90
        minTemperature =
            try c.decodeIfPresent(Double.self, forKey: .minTemperature) ?? 30
        selectedSensorKeys =
            try c.decodeIfPresent([String].self, forKey: .selectedSensorKeys)
            ?? []
        manualRPM =
            try c.decodeIfPresent(Double.self, forKey: .manualRPM) ?? 1500
        minRPM = try c.decodeIfPresent(Double.self, forKey: .minRPM)
        maxRPM = try c.decodeIfPresent(Double.self, forKey: .maxRPM)
        filterEnabled =
            try c.decodeIfPresent(Bool.self, forKey: .filterEnabled) ?? false
        filterFactor =
            try c.decodeIfPresent(Double.self, forKey: .filterFactor) ?? 1.0
    }

    func effectiveMinRPM(fanMinRPM: Double) -> Double { minRPM ?? fanMinRPM }

    func effectiveMaxRPM(fanMaxRPM: Double) -> Double { maxRPM ?? fanMaxRPM }
}
