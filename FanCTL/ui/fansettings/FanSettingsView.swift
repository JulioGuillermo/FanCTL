import SwiftUI

/// Configuration sheet for a single fan: temperature range to maintain and
/// which sensors control it.
public struct FanSettingsView: View {
    let fan: FanInfo
    let sensors: [SensorInfo]
    @ObservedObject var store: SettingsStore
    var onClose: () -> Void = {}

    @State private var config: FanSettings
    @State private var sortMode: SensorSortMode = .alphabetical

    init(
        fan: FanInfo,
        sensors: [SensorInfo],
        store: SettingsStore,
        onClose: @escaping () -> Void = {}
    ) {
        self.fan = fan
        self.sensors = sensors
        self.store = store
        self.onClose = onClose
        _config = State(initialValue: store.fanSettings(for: fan))
    }

    private var calculation: FanSpeedCalculation {
        FanSpeedCalculation.compute(fan: fan, config: config, sensors: sensors)
    }

    private var temperatureSensors: [SensorInfo] {
        sensors.filter(\.isTemperature)
    }

    private var selectedCount: Int {
        temperatureSensors.filter { config.selectedSensorKeys.contains($0.id) }
            .count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FanSettingsTitle(fanName: fan.name, onClose: onClose)

            Divider()

            NavigationSplitView {
                VStack {
                    FanSettingSpeedLimits(
                        fan: fan,
                        config: config
                    )

                    if config.mode == .automatic {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temperatures to maintain")
                                .font(.headline)

                            temperatureRow(
                                label: "Max temperature (°C)",
                                value: $config.maxTemperature
                            )
                            temperatureRow(
                                label: "Min temperature (°C)",
                                value: $config.minTemperature
                            )

                            Text(
                                "Below the minimum the speed is minimal; above the maximum, maximal."
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                    
                    summarySection
                }
                .padding(14)
                .frame(width: 300)
            } detail: {
                VStack {
                    FanSettingMode(mode: $config.mode)

                    Divider()

                    if config.mode == .manual {
                        manualSpeedSection
                            .padding(.top, 4)
                    } else if config.mode == .automatic {
                        // Sensors that control this fan
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sensors controlling this fan")
                                    .font(.headline)
                                Spacer()
                                SensorSortMenu(sortMode: $sortMode)
                                Button("All") { selectAll() }
                                Button("None") {
                                    config.selectedSensorKeys = []
                                }
                            }
                            .font(.caption)

                            if !temperatureSensors.isEmpty {
                                SensorSelectionList(
                                    sensors: temperatureSensors,
                                    sortMode: $sortMode,
                                    isSelected: {
                                        config.selectedSensorKeys.contains(
                                            $0.id
                                        )
                                    },
                                    onToggle: { toggle($0) },
                                    onSetSelected: {
                                        setSelected($0, selected: $1)
                                    }
                                )
                                .frame(minHeight: 240, maxHeight: 320)
                                .clipped()
                            } else {
                                Text("No sensors detected.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        // Speed smoothing: blend the calculated speed with the previous one
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(
                                "Speed smoothing",
                                isOn: $config.filterEnabled
                            )
                            .font(.headline)

                            if config.filterEnabled {
                                HStack(spacing: 10) {
                                    Text("Fixed")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: $config.filterFactor,
                                        in: 0...1,
                                        step: 0.05
                                    )
                                    Text("Unfiltered")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Text(
                                    String(
                                        format:
                                            "Speed = previous × %.0f%% + calculated × %.0f%%",
                                        (1 - config.filterFactor) * 100,
                                        config.filterFactor * 100
                                    )
                                )
                                .font(.caption2)
                                .foregroundColor(.secondary)

                                if config.filterFactor < 0.01 {
                                    Text(
                                        "Fixed: the fan stays at its current speed."
                                    )
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(
            width: 800,
            height: 700
        )
        .onAppear {
            // By default, if there is no saved selection, select all sensors
            if config.selectedSensorKeys.isEmpty && !temperatureSensors.isEmpty
            {
                config.selectedSensorKeys = temperatureSensors.map(\.id)
            }
            if config.manualRPM < fan.minRPM || config.manualRPM > fan.maxRPM {
                config.manualRPM = fan.minRPM + (fan.maxRPM - fan.minRPM) * 0.3
            }
        }
        .onChange(of: config.maxTemperature) { oldValue, newValue in
            if newValue <= config.minTemperature {
                config.minTemperature = max(0, newValue - 1)
            }
        }
        .onChange(of: config.minTemperature) { oldValue, newValue in
            if newValue >= config.maxTemperature {
                config.maxTemperature = newValue + 1
            }
        }
        .onChange(of: config) { oldValue, newValue in
            store.updateFanSettings(newValue)
        }
    }

    private var manualSpeedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Fixed speed")
                    .foregroundColor(.secondary)
                Spacer()
                TextField(
                    "RPM",
                    value: Binding(
                        get: { config.manualRPM },
                        set: { config.manualRPM = min(max($0, effMin), effMax) }
                    ),
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
            }

            Slider(
                value: Binding(
                    get: { config.manualRPM },
                    set: { config.manualRPM = $0 }
                ),
                in: effMin...max(effMax, effMin),
                step: 50
            )

            Text(
                "Range: \(Int(effMin)) – \(Int(effMax)) RPM (fan's real range: \(Int(fan.minRPM)) – \(Int(fan.maxRPM)))"
            )
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }

    private var summarySection: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if config.mode == .automatic {
                    Text(
                        "Sensors: \(selectedCount)/\(temperatureSensors.count)"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    if let maxTemp = calculation.maxSelectedTemperature {
                        Text(String(format: "Max: %.1f °C", maxTemp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Mode: \(config.mode.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if config.mode == .automatic {
                    Text(
                        String(
                            format: "Normalized: %.0f%%",
                            calculation.normalizedValue * 100
                        )
                    )
                    .font(.caption)
                    .bold()
                }
                if let target = summaryTargetRPM {
                    Text("Target speed: \(Int(target)) RPM")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
    }

    private var summaryTargetRPM: Double? {
        switch config.mode {
        case .automatic:
            return calculation.targetRPM
        case .manual:
            return config.manualRPM
        case .off:
            return effMin
        case .maximum:
            return effMax
        }
    }

    private var effMin: Double { config.minRPM ?? fan.minRPM }
    private var effMax: Double { config.maxRPM ?? fan.maxRPM }

    private func temperatureRow(label: String, value: Binding<Double>)
        -> some View
    {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
            Stepper("", value: value, in: 0...150, step: 1)
                .labelsHidden()
        }
    }

    private func toggle(_ sensor: SensorInfo) {
        if let index = config.selectedSensorKeys.firstIndex(of: sensor.id) {
            config.selectedSensorKeys.remove(at: index)
        } else {
            config.selectedSensorKeys.append(sensor.id)
        }
    }

    private func setSelected(_ sensors: [SensorInfo], selected: Bool) {
        for sensor in sensors {
            if selected {
                if !config.selectedSensorKeys.contains(sensor.id) {
                    config.selectedSensorKeys.append(sensor.id)
                }
            } else {
                config.selectedSensorKeys.removeAll { $0 == sensor.id }
            }
        }
    }

    private func selectAll() {
        config.selectedSensorKeys = temperatureSensors.map(\.id)
    }
}
