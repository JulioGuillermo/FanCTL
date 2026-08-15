import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var sensors: [SensorInfo] = []
    @State private var fans: [FanInfo] = []
    @State private var connectionStatus: String = "No iniciado"
    @State private var isConnected: Bool = false
    @State private var selectedSensor: SensorInfo? = nil
    @State private var isScanning: Bool = false
    @State private var autoRefreshEnabled: Bool = true

    @StateObject private var sensorSelector = SensorSelectionController()

    // Timer para refresco continuo en vivo (ideal para Mac mini sin Sandbox)
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // Panel Izquierdo (pequeño): Sensores Térmicos con selección
            LeftPanelSensorsView(
                sensors: sensors,
                selector: sensorSelector,
                selectedSensor: $selectedSensor
            )
            .frame(width: 330)

            Divider()

            // Panel Derecho (expansible): Estado de Conexión y Ventiladores
            RightPanelFansView(
                fans: fans,
                isConnected: isConnected,
                connectionStatus: connectionStatus,
                isScanning: isScanning,
                autoRefreshEnabled: $autoRefreshEnabled,
                onRefresh: refreshSensors
            )
            .frame(minWidth: 450, maxWidth: .infinity)
        }
        .frame(minWidth: 900, minHeight: 580)
        .onAppear {
            refreshSensors()
        }
        .onReceive(timer) { _ in
            if autoRefreshEnabled && !isScanning {
                refreshSensors()
            }
        }
        .sheet(item: $selectedSensor) { sensor in
            SensorDetailView(sensor: sensor)
        }
    }

    private func refreshSensors() {
        isScanning = true
        AppLog.log("[Content] refreshSensors() iniciado")

        let snapshot = SensorsReader().readAll()
        self.sensors = snapshot.sensors
        sensorSelector.updateSensors(snapshot.sensors)
        self.fans = snapshot.fans
        self.isConnected = snapshot.connectionOk
        self.connectionStatus = snapshot.connectionOk ? "Conectado (Sin Sandbox)" : "Error de Conexión"
        AppLog.log("[Content] Sensores totales: \(snapshot.sensors.count), Ventiladores: \(snapshot.fans.count), connectionOk: \(snapshot.connectionOk)")

        isScanning = false
    }
}

/// Panel izquierdo compacto con la lista de sensores térmicos seleccionables
struct LeftPanelSensorsView: View {
    let sensors: [SensorInfo]
    @ObservedObject var selector: SensorSelectionController
    @Binding var selectedSensor: SensorInfo?

    private var maxTempText: String {
        guard let max = selector.maxTemperature else { return "—" }
        return String(format: "%.1f °C", max)
    }

    private var maxTempColor: Color {
        guard let max = selector.maxTemperature else { return .secondary }
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

            // Máxima temperatura de los seleccionados + acciones
            HStack(spacing: 8) {
                Label(maxTempText, systemImage: "thermometer.high")
                    .font(.system(.body, design: .monospaced))
                    .bold()
                    .foregroundColor(maxTempColor)

                Spacer()

                Button("Todo") { selector.selectAll() }
                Button("Ninguno") { selector.selectNone() }
            }
            .font(.caption)
            .padding(.horizontal)

            Divider()

            // Lista limpia de Sensores Térmicos con selección
            if !sensors.isEmpty {
                List(sensors, id: \.id) { sensor in
                    SensorRowView(
                        sensor: sensor,
                        isSelected: selector.isSelected(sensor),
                        onToggleSelection: { selector.toggle(sensor) },
                        onTapDetails: { selectedSensor = sensor }
                    )
                }
                .listStyle(.plain)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Sin datos de sensores")
                        .font(.headline)
                    Text("Haz clic en 'Reescanear Ahora' para detectar lecturas térmicas.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Contador de selección
            Text("\(selector.selectedCount) / \(sensors.count) seleccionados")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 6)
        }
        .background(Color.secondary.opacity(0.04))
    }
}

/// Panel derecho principal y expansible con el estado y los ventiladores
struct RightPanelFansView: View {
    let fans: [FanInfo]
    let isConnected: Bool
    let connectionStatus: String
    let isScanning: Bool
    @Binding var autoRefreshEnabled: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Encabezado del Panel adaptado a Mac mini
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "macmini.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Mac mini • SMC")
                        .font(.title3)
                        .bold()
                }

                // Indicador de Estado y Sandbox
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Direct Access")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // Lista de Ventiladores (ocupa todo el espacio disponible)
            if !fans.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(fans) { fan in
                            FanRowView(fan: fan)
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

            // Interruptor de actualización en tiempo real
            Toggle(isOn: $autoRefreshEnabled) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .foregroundColor(autoRefreshEnabled ? .green : .gray)
                    Text("Monitoreo en vivo (2s)")
                        .font(.caption)
                        .bold()
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal)

            // Botón global de rescanear
            Button(action: onRefresh) {
                HStack {
                    Image(systemName: isScanning ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .animation(isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isScanning)
                    Text(isScanning ? "Escaneando..." : "Reescanear Ahora")
                        .bold()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color.secondary.opacity(0.04))
    }
}

/// Fila individual para cada sensor térmico con checkbox de selección
struct SensorRowView: View {
    let sensor: SensorInfo
    var isSelected: Bool
    var onToggleSelection: () -> Void
    var onTapDetails: () -> Void

    private var temperatureColor: Color {
        if sensor.value < 45 { return .green }
        if sensor.value < 65 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox de selección
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: sensor.category.iconName)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(sensor.rawKey)
                    .font(.system(.body, design: .monospaced))
                    .bold()
                    .strikethrough(!isSelected, color: .secondary)

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
    ContentView()
}
