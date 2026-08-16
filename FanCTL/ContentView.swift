import SwiftUI
internal import Combine

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var daemonClient: FanDaemonClient
    @EnvironmentObject private var fanController: FanController
    @EnvironmentObject private var hardwareMonitor: HardwareMonitor

    @State private var sensors: [SensorInfo] = []
    @State private var fans: [FanInfo] = []
    @State private var connectionStatus: String = "Not started"
    @State private var isConnected: Bool = false
    @State private var selectedSensor: SensorInfo? = nil
    @State private var settingsFan: FanInfo? = nil
    @State private var isScanning: Bool = false
    @State private var showingGeneralSettings: Bool = false
    @State private var lastRefresh: Date = .distantPast

    @StateObject private var settingsStore = SettingsStore()

    // 0.5s ticker to respect the configured rescan interval
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // Left panel (small): read-only thermal sensors
            LeftPanelSensorsView(
                sensors: sensors,
                selectedSensor: $selectedSensor,
                maxTempSensorKeys: settingsStore.settings.maxTempSensorKeys
            )
            .frame(minWidth: 330, maxWidth: 380)

            Divider()

            // Right panel (expandable): Machine, Status and Fans
            RightPanelFansView(
                fans: fans,
                systemInfo: SystemInfo.shared,
                isConnected: isConnected,
                connectionStatus: connectionStatus,
                controlActive: daemonClient.isAvailable || fanController.canControlHardware,
                controlError: daemonClient.lastError,
                isRequestingPermissions: daemonClient.isRequestingPermissions,
                modeFor: mode(for:),
                desiredRPMFor: desiredRPM(for:),
                manualRPMFor: manualRPM(for:),
                minSpeedRPMFor: minSpeedRPM(for:),
                maxSpeedRPMFor: maxSpeedRPM(for:),
                onChangeMode: { fan, mode in
                    changeMode(mode, for: fan)
                },
                onManualRPMChange: { fan, rpm in
                    changeManualRPM(rpm, for: fan)
                },
                onGeneralSettings: { showingGeneralSettings = true },
                onFanSettings: { settingsFan = $0 },
                onRequestControl: { requestControlPermissions() }
            )
            .frame(minWidth: 450, maxWidth: .infinity)
        }
        .frame(minWidth: 960, minHeight: 640)
        .onAppear {
            fanController.checkPrivileges()
            refreshSensors()
        }
        .onReceive(ticker) { _ in
            guard !isScanning else { return }
            let interval = settingsStore.settings.refreshInterval
            if Date().timeIntervalSince(lastRefresh) >= interval {
                refreshSensors()
            }
        }
        .onChange(of: scenePhase) { _, _ in
            // When the window is closed the app hides to the menu bar and
            // control continues. Only real closing (Cmd+Q) restores the system.
        }
        .background(WindowCloseHider())
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            restoreSystemControl()
        }
        .sheet(item: $selectedSensor) { sensor in
            SensorDetailView(sensor: sensor)
        }
        .sheet(item: $settingsFan) { fan in
            FanSettingsView(fan: fan, sensors: sensors, store: settingsStore)
        }
        .sheet(isPresented: $showingGeneralSettings) {
            GeneralSettingsView(store: settingsStore, daemon: daemonClient, sensors: sensors)
        }
        .onReceive(daemonClient.$isAvailable) { available in
            // If the daemon becomes available (or goes down), recompute control
            if available {
                fanController.recheckPrivileges()
                refreshSensors()
            } else {
                fanController.recheckPrivileges()
            }
        }
    }

    private func mode(for fan: FanInfo) -> FanMode {
        settingsStore.fanSettings(for: fan).mode
    }

    private func desiredRPM(for fan: FanInfo) -> Double {
        let config = settingsStore.fanSettings(for: fan)
        let lowRPM = config.effectiveMinRPM(fanMinRPM: fan.minRPM)
        let highRPM = config.effectiveMaxRPM(fanMaxRPM: fan.maxRPM)
        switch config.mode {
        case .automatic:
            let calc = FanSpeedCalculation.compute(fan: fan, config: config, sensors: sensors)
            return calc.targetRPM ?? lowRPM
        case .manual:
            return min(max(config.manualRPM, lowRPM), highRPM)
        case .off:
            return lowRPM
        case .maximum:
            return highRPM
        }
    }

    private func manualRPM(for fan: FanInfo) -> Double {
        let config = settingsStore.fanSettings(for: fan)
        return min(max(config.manualRPM, config.effectiveMinRPM(fanMinRPM: fan.minRPM)), config.effectiveMaxRPM(fanMaxRPM: fan.maxRPM))
    }

    private func minSpeedRPM(for fan: FanInfo) -> Double {
        settingsStore.fanSettings(for: fan).effectiveMinRPM(fanMinRPM: fan.minRPM)
    }

    private func maxSpeedRPM(for fan: FanInfo) -> Double {
        settingsStore.fanSettings(for: fan).effectiveMaxRPM(fanMaxRPM: fan.maxRPM)
    }

    private func changeMode(_ mode: FanMode, for fan: FanInfo) {
        var config = settingsStore.fanSettings(for: fan)
        config.mode = mode
        settingsStore.updateFanSettings(config)
        AppLog.log("[Content] Fan \(fan.id) mode → \(mode.rawValue)")
    }

    private func changeManualRPM(_ rpm: Double, for fan: FanInfo) {
        var config = settingsStore.fanSettings(for: fan)
        config.manualRPM = min(max(rpm, config.effectiveMinRPM(fanMinRPM: fan.minRPM)), config.effectiveMaxRPM(fanMaxRPM: fan.maxRPM))
        settingsStore.updateFanSettings(config)
    }

    private func requestControlPermissions() {
        daemonClient.startDaemon()
    }

    private func applyFanControl() {
        guard !fans.isEmpty else { return }
        for fan in fans {
            let config = settingsStore.fanSettings(for: fan)
            let desired = desiredRPM(for: fan)
            fanController.setSpeed(desired, toFan: fan.id)
            AppLog.log("[Content] F\(fan.id) mode=\(config.mode.rawValue) target=\(Int(desired)) RPM")
        }
    }

    private func restoreSystemControl() {
        guard !fans.isEmpty else { return }
        for fan in fans {
            fanController.restoreSystemControl(toFan: fan.id)
        }
    }

    private func refreshSensors() {
        lastRefresh = Date()
        isScanning = true
        AppLog.log("[Content] refreshSensors() started")

        let snapshot = SensorsReader().readAll()
        self.sensors = snapshot.sensors
        self.fans = snapshot.fans
        self.isConnected = snapshot.connectionOk
        self.connectionStatus = snapshot.connectionOk ? "Connected" : "Connection error"
        hardwareMonitor.update(
            sensors: snapshot.sensors,
            fans: snapshot.fans,
            maxTempSensorKeys: settingsStore.settings.maxTempSensorKeys
        )
        AppLog.log("[Content] Total sensors: \(snapshot.sensors.count), Fans: \(snapshot.fans.count), connectionOk: \(snapshot.connectionOk)")

        isScanning = false
        applyFanControl()
    }
}

/// Compact left panel with the read-only list of thermal sensors
struct LeftPanelSensorsView: View {
    let sensors: [SensorInfo]
    @Binding var selectedSensor: SensorInfo?
    var maxTempSensorKeys: [String] = []

    @State private var sortMode: SensorSortMode = .hottest

    private var sortedSensorsList: [SensorInfo] {
        sortedSensors(sensors, by: sortMode)
    }

    private var maxTempSensor: SensorInfo? {
        if maxTempSensorKeys.isEmpty {
            return sensors.max { $0.value < $1.value }
        }
        let pool = sensors.filter { maxTempSensorKeys.contains($0.id) }
        return pool.max { $0.value < $1.value }
    }

    private var maxTempText: String {
        guard let sensor = maxTempSensor else { return "—" }
        return String(format: "%.1f °C", sensor.value)
    }

    private var maxTempColor: Color {
        guard let sensor = maxTempSensor else { return .secondary }
        return TemperatureIndicator.color(for: sensor.value)
    }

    private var maxTempIcon: String {
        guard let sensor = maxTempSensor else { return "thermometer.medium" }
        return TemperatureIndicator.iconName(for: sensor.value)
    }

    private var maxTempSourceName: String {
        guard let sensor = maxTempSensor else { return "No data" }
        return maxTempSensorKeys.isEmpty ? "Auto · \(sensor.rawKey)" : sensor.rawKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Sensor section header
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thermal sensors")
                            .font(.title3)
                            .bold()
                        Text("Direct IOKit access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    SensorSortMenu(sortMode: $sortMode)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Maximum temperature (from the selected sensor or the hottest)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label(maxTempText, systemImage: maxTempIcon)
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .foregroundColor(maxTempColor)
                    Text(maxTempSourceName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(sensors.count) active")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Divider()

            // Clean thermal sensor list
            if !sensors.isEmpty {
                List(sortedSensorsList, id: \.id) { sensor in
                    SensorRowView(
                        sensor: sensor,
                        onTapDetails: { selectedSensor = sensor }
                    )
                }
                .listStyle(.plain)
                .frame(minHeight: 240)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No sensor data")
                        .font(.headline)
                    Text("Waiting for the first hardware read.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.secondary.opacity(0.04))
    }
}

/// Main expandable right panel with the machine, status and fans
struct RightPanelFansView: View {
    let fans: [FanInfo]
    let systemInfo: SystemInfo
    let isConnected: Bool
    let connectionStatus: String
    let controlActive: Bool
    let controlError: String?
    let isRequestingPermissions: Bool
    let modeFor: (FanInfo) -> FanMode
    let desiredRPMFor: (FanInfo) -> Double
    let manualRPMFor: (FanInfo) -> Double
    let minSpeedRPMFor: (FanInfo) -> Double
    let maxSpeedRPMFor: (FanInfo) -> Double
    let onChangeMode: (FanInfo, FanMode) -> Void
    let onManualRPMChange: (FanInfo, Double) -> Void
    let onGeneralSettings: () -> Void
    let onFanSettings: (FanInfo) -> Void
    let onRequestControl: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Panel header with the detected machine
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: systemInfo.type.iconName)
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(systemInfo.type.rawValue)
                                .font(.title3)
                                .bold()
                            Text("\(systemInfo.computerName) • \(systemInfo.modelIdentifier)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button(action: onGeneralSettings) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("General settings")
                }

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if controlActive {
                        Text("Control active")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else {
                        Text("Control requires root")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // Permission banner: asks to enable fan control
            if !controlActive {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fan control disabled")
                            .font(.caption)
                            .bold()
                        Text("Background control requires administrator privileges.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Start control") { onRequestControl() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isRequestingPermissions)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 4)

                if let controlError {
                    Text(controlError)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }

                if isRequestingPermissions {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Requesting administrator privileges…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }

            // Fan list (takes all available space)
            if !fans.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(fans) { fan in
                            FanRowView(
                                fan: fan,
                                mode: modeFor(fan),
                                desiredRPM: desiredRPMFor(fan),
                                manualRPM: manualRPMFor(fan),
                                minSpeedRPM: minSpeedRPMFor(fan),
                                maxSpeedRPM: maxSpeedRPMFor(fan),
                                controlActive: controlActive,
                                isRequestingPermissions: isRequestingPermissions,
                                onChangeMode: { onChangeMode(fan, $0) },
                                onManualRPMChange: { onManualRPMChange(fan, $0) },
                                onRequestControl: onRequestControl,
                                onSettings: { onFanSettings(fan) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // State for fanless Macs (e.g. MacBook Air)
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wind")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No fans")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("This machine uses passive cooling or does not report fans.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .background(Color.secondary.opacity(0.04))
    }
}

/// Individual row for each thermal sensor (read-only)
struct SensorRowView: View {
    let sensor: SensorInfo
    var onTapDetails: () -> Void = {}

    private var temperatureColor: Color {
        if sensor.value < 45 { return .green }
        if sensor.value < 65 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: sensor.category.iconName)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(sensor.rawKey)
                    .font(.system(.body, design: .monospaced))
                    .bold()

                Text("\(SensorDescriptions.shortName(for: sensor.rawKey)) · \(sensor.source.rawValue)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .help(sensor.descriptionText)

            Spacer()

            Text(String(format: "%.1f °C", sensor.value))
                .font(.system(.body, design: .monospaced))
                .bold()
                .foregroundColor(temperatureColor)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapDetails()
        }
    }
}

/// Full IOKit metadata inspection modal
struct SensorDetailView: View {
    let sensor: SensorInfo
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: sensor.category.iconName)
                    .font(.title)
                    .foregroundColor(.blue)
                Text(sensor.rawKey)
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Close") { dismiss() }
            }

            Divider()

            Group {
                MetaRow(label: "Current Temperature", value: String(format: "%.2f °C", sensor.value))
                MetaRow(label: "Category", value: sensor.category.rawValue)
                MetaRow(label: "Source (API)", value: sensor.source.rawValue)
                MetaRow(label: "Thermal Zone", value: sensor.thermalZone ?? "N/A")

                if let up = sensor.usagePage {
                    MetaRow(label: "PrimaryUsagePage", value: String(format: "0x%04X", up))
                }
                if let u = sensor.usage {
                    MetaRow(label: "PrimaryUsage", value: "\(u)")
                }
            }

            Divider()

            Text("Sensor explanation")
                .font(.headline)

            Text(sensor.descriptionText)
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(width: 420, height: 430)
    }
}

struct MetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    let daemon = FanDaemonClient()
    return ContentView()
        .environmentObject(daemon)
        .environmentObject(FanController(daemon: daemon))
        .environmentObject(HardwareMonitor())
}
