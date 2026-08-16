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
    @State private var isScanning: Bool = false
    @State private var lastRefresh: Date = .distantPast

    @StateObject private var settingsStore = SettingsStore()
    @State private var panelManager = LiquidGlassPanelManager()

    // 0.5s ticker to respect the configured rescan interval
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Animated decorative background (drifting blobs + blurred fan)
            AnimatedBackground()

            // Finder-style split view: sensors sidebar + machine/fans detail
            NavigationSplitView {
                LeftPannel(
                    sensors: sensors,
                    selectedSensor: $selectedSensor,
                    maxTempSensorKeys: settingsStore.settings.maxTempSensorKeys
                )
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            } detail: {
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
                    onGeneralSettings: { presentGeneralSettings() },
                    onFanSettings: { presentFanSettings($0) },
                    onRequestControl: { requestControlPermissions() }
            )
                .frame(minWidth: 480, maxWidth: .infinity)
            }
        }
        .navigationTitle("FanCTL")
        .preferredColorScheme(.dark)
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
                .presentationBackground(.ultraThinMaterial)
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

    private func presentGeneralSettings() {
        panelManager.present(
            GeneralSettingsView(
                store: settingsStore,
                daemon: daemonClient,
                sensors: sensors,
                onClose: { panelManager.close() }
            )
            .liquidGlassPanel(),
            relativeTo: NSApp.keyWindow
        )
    }

    private func presentFanSettings(_ fan: FanInfo) {
        panelManager.present(
            FanSettingsView(
                fan: fan,
                sensors: sensors,
                store: settingsStore,
                onClose: { panelManager.close() }
            )
            .liquidGlassPanel(),
            relativeTo: NSApp.keyWindow
        )
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
            let target = calc.targetRPM ?? lowRPM
            if config.filterEnabled {
                let previous = fanController.appliedSpeeds[fan.id] ?? fan.currentRPM
                let blended = previous * (1 - config.filterFactor) + target * config.filterFactor
                return min(max(blended, lowRPM), highRPM)
            }
            return min(max(target, lowRPM), highRPM)
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

    /// Keeps the sensor list stable between scans. A sensor that fails to read
    /// on a single scan (transient AppleSMC hiccup, core parked) stays in the
    /// list with its last known value instead of disappearing and making the
    /// list/scroll position jump.
    private static func stabilizedSensors(_ newSensors: [SensorInfo],
                                          against previous: [SensorInfo]) -> [SensorInfo] {
        var byID = Dictionary(uniqueKeysWithValues: newSensors.map { ($0.id, $0) })
        for stale in previous where byID[stale.id] == nil {
            byID[stale.id] = stale
        }
        return Array(byID.values)
    }

    private func refreshSensors() {
        lastRefresh = Date()
        isScanning = true
        AppLog.log("[Content] refreshSensors() started")

        // The actual hardware scan (SMC/HID IPC reads of ~200 sensors) is
        // slow and blocks the main thread, freezing the UI and the fan
        // animation for an instant on every refresh. Run the read + merge on
        // a background queue and only apply the result on the main thread.
        let previousSensors = sensors
        let maxTempKeys = settingsStore.settings.maxTempSensorKeys

        DispatchQueue.global(qos: .userInitiated).async {
            let snapshot = SensorsReader().readAll()
            let mergedSensors = Self.stabilizedSensors(snapshot.sensors, against: previousSensors)

            DispatchQueue.main.async {
                self.sensors = mergedSensors
                self.fans = snapshot.fans
                self.isConnected = snapshot.connectionOk
                self.connectionStatus = snapshot.connectionOk ? "Connected" : "Connection error"
                self.hardwareMonitor.update(
                    sensors: snapshot.sensors,
                    fans: snapshot.fans,
                    maxTempSensorKeys: maxTempKeys
                )
                AppLog.log("[Content] Total sensors: \(snapshot.sensors.count), Fans: \(snapshot.fans.count), connectionOk: \(snapshot.connectionOk)")

                self.isScanning = false
                self.applyFanControl()
            }
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
                MetaRow(label: "Current Value", value: sensor.displayValue)
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
