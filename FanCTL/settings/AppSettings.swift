public struct AppSettings: Codable, Equatable {
    /// Hardware rescan interval in seconds.
    var refreshInterval: Double = 2.0
    /// Sensors feeding the max temperature indicator; empty = automatic (hottest).
    var maxTempSensorKeys: [String] = []
    /// Per-fan configuration.
    var fans: [FanSettings] = []

    enum CodingKeys: String, CodingKey {
        case refreshInterval, maxTempSensorKey, maxTempSensorKeys, fans
    }

    init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        refreshInterval = try c.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 2.0
        if let keys = try c.decodeIfPresent([String].self, forKey: .maxTempSensorKeys) {
            maxTempSensorKeys = keys
        } else if let single = try c.decodeIfPresent(String.self, forKey: .maxTempSensorKey) {
            maxTempSensorKeys = [single]
        } else {
            maxTempSensorKeys = []
        }
        fans = try c.decodeIfPresent([FanSettings].self, forKey: .fans) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(refreshInterval, forKey: .refreshInterval)
        try c.encode(maxTempSensorKeys, forKey: .maxTempSensorKeys)
        try c.encode(fans, forKey: .fans)
    }
}
