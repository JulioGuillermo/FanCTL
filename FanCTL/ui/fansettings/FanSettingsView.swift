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

            Divider()

            HStack {
                VStack {
                    FanSettingsTitle(fan: fan, onClose: onClose)

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
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .padding(14)
                .frame(width: 300)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 18)
                )

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

                        FanSettingSensorList(
                            temperatureSensors: sensors,
                            config: $config
                        )
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
            .padding(10)
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

}
