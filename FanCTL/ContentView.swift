import SwiftUI
internal import Combine

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var daemonClient: FanDaemonClient
    @EnvironmentObject private var fanController: FanController
    @EnvironmentObject private var hardwareMonitor: HardwareMonitor

    @State private var sensors: [SensorInfo] = []
    @State private var fans: [FanInfo] = []
    @State private var connectionStatus: String = "No iniciado"
    @State private var isConnected: Bool = false
    @State private var selectedSensor: SensorInfo? = nil
    @State private var settingsFan: FanInfo? = nil
    @State private var isScanning: Bool = false
    @State private var showingGeneralSettings: Bool = false
    @State private var lastRefresh: Date = .distantPast

    @StateObject private var settingsStore = SettingsStore()

    // Ticker de 0.5s para respetar el intervalo configurado de reescaneo
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // Panel Izquierdo (pequeño): Sensores Térmicos en solo lectura
            LeftPanelSensorsView(
                sensors: sensors,
                selectedSensor: $selectedSensor
            )
            .frame(minWidth: 330, maxWidth: 380)

            Divider()

            // Panel Derecho (expansible): Equipo, Estado y Ventiladores
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
            // Al cerrar la ventana la app se oculta a la barra de menú y el
            // control continúa. Solo el cierre real (Cmd+Q) restaura el sistema.
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
            GeneralSettingsView(store: settingsStore, daemon: daemonClient)
        }
        .onReceive(daemonClient.$isAvailable) { available in
            // Si el daemon pasa a estar disponible (o se cae), recalcular el control
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
        AppLog.log("[Content] Fan \(fan.id) modo → \(mode.rawValue)")
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
            AppLog.log("[Content] F\(fan.id) modo=\(config.mode.rawValue) objetivo=\(Int(desired)) RPM")
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
        AppLog.log("[Content] refreshSensors() iniciado")

        let snapshot = SensorsReader().readAll()
        self.sensors = snapshot.sensors
        self.fans = snapshot.fans
        self.isConnected = snapshot.connectionOk
        self.connectionStatus = snapshot.connectionOk ? "Conectado" : "Error de Conexión"
        hardwareMonitor.update(sensors: snapshot.sensors, fans: snapshot.fans)
        AppLog.log("[Content] Sensores totales: \(snapshot.sensors.count), Ventiladores: \(snapshot.fans.count), connectionOk: \(snapshot.connectionOk)")

        isScanning = false
        applyFanControl()
    }
}

/// Panel izquierdo compacto con la lista de sensores térmicos en solo lectura
struct LeftPanelSensorsView: View {
    let sensors: [SensorInfo]
    @Binding var selectedSensor: SensorInfo?

    private var maxTempText: String {
        guard let max = sensors.map(\.value).max() else { return "—" }
        return String(format: "%.1f °C", max)
    }

    private var maxTempColor: Color {
        guard let max = sensors.map(\.value).max() else { return .secondary }
        if max < 45 { return .green }
        if max < 65 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Encabezado de la Sección de Sensores
            VStack(alignment: .leading, spacing: 2) {
                Text("Sensores Térmicos")
                    .font(.title3)
                    .bold()
                Text("Acceso IOKit directo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            // Máxima temperatura de todos los sensores
            HStack {
                Label(maxTempText, systemImage: "thermometer.high")
                    .font(.system(.body, design: .monospaced))
                    .bold()
                    .foregroundColor(maxTempColor)

                Spacer()

                Text("\(sensors.count) activos")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Divider()

            // Lista limpia de Sensores Térmicos
            if !sensors.isEmpty {
                List(sensors, id: \.id) { sensor in
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
                    Text("Sin datos de sensores")
                        .font(.headline)
                    Text("Esperando la primera lectura del hardware.")
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

/// Panel derecho principal y expansible con el equipo, el estado y los ventiladores
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
            // Encabezado del Panel con el equipo real detectado
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
                    .help("Ajustes generales")
                }

                // Indicador de Estado
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if controlActive {
                        Text("Control activo")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else {
                        Text("Control requiere root")
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

            // Banner de permisos: pide activar el control del ventilador
            if !controlActive {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Control del ventilador desactivado")
                            .font(.caption)
                            .bold()
                        Text("El control en background necesita permisos de administrador.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Iniciar control") { onRequestControl() }
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
                        Text("Solicitando permisos de administrador…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }

            // Lista de Ventiladores (ocupa todo el espacio disponible)
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
                // Estado para Macs Fanless (ej. MacBook Air)
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wind")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Sin ventiladores")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Este equipo utiliza refrigeración pasiva o no reporta ventiladores.")
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

/// Fila individual para cada sensor térmico (solo lectura)
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

                Text(sensor.source.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

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

/// Modal de inspección completa de metadatos de IOKit
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
                Button("Cerrar") { dismiss() }
            }

            Divider()

            Group {
                MetaRow(label: "Temperatura Actual", value: String(format: "%.2f °C", sensor.value))
                MetaRow(label: "Categoría", value: sensor.category.rawValue)
                MetaRow(label: "Origen (API)", value: sensor.source.rawValue)
                MetaRow(label: "Zona Térmica (ThermalZone)", value: sensor.thermalZone ?? "N/A")

                if let up = sensor.usagePage {
                    MetaRow(label: "PrimaryUsagePage", value: String(format: "0x%04X", up))
                }
                if let u = sensor.usage {
                    MetaRow(label: "PrimaryUsage", value: "\(u)")
                }
            }

            Divider()

            Text("Explicación del Sensor")
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
