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

    private var temperatureSensors: [SensorInfo] {
        sensors.filter(\.isTemperature)
    }

    private var effMin: Double { config.minRPM ?? fan.minRPM }
    private var effMax: Double { config.maxRPM ?? fan.maxRPM }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FanSettingsTitle(fanName: fan.name, onClose: onClose)

            Divider()

            NavigationSplitView {
                VStack {
                    FanSettingSpeedLimits(
                        fan: fan,
                        effMin: effMin,
                        effMax: effMax,
                        config: $config
                    )

                    if config.mode == .automatic {
                        Divider()

                        FanSettingTempLimits(config: $config)
                    }

                    Spacer()

                    FanSettingSummary(
                        fan: fan,
                        config: config,
                        sensors: sensors,
                        temperatureSensors: temperatureSensors,
                        effMin: effMin,
                        effMax: effMax
                    )
                }
                .padding(14)
                .frame(width: 300)
            } detail: {
                VStack {
                    FanSettingMode(mode: $config.mode)

                    Divider()

                    if config.mode == .manual {
                        FanSettingManualSpeedSection(
                            fan: fan,
                            effMin: effMin,
                            effMax: effMax,
                            config: $config
                        )
                    } else if config.mode == .automatic {
                        FanSettingSmoothing(config: $config)
                        
                        Divider()

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

                    }
                }
                .padding(10)
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
