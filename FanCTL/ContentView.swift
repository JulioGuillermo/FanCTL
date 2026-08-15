import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var sensors: [SensorInfo] = []
    @State private var fans: [FanInfo] = []
    @State private var connectionStatus: String = "No iniciado"
    @State private var isConnected: Bool = false
    @State private var selectedSensor: SensorInfo? = nil
    @State private var filterCategory: SensorCategory? = nil
    @State private var isScanning: Bool = false
    @State private var autoRefreshEnabled: Bool = true

    // Timer para refresco continuo en vivo (ideal para Mac mini sin Sandbox)
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // Panel Izquierdo: Control de Estado y Ventiladores
            LeftPanelFansView(
                fans: fans,
                isConnected: isConnected,
                connectionStatus: connectionStatus,
                isScanning: isScanning,
                autoRefreshEnabled: $autoRefreshEnabled,
                onRefresh: refreshSensors
            )
            .frame(width: 330)

            Divider()

            // Panel Derecho: Sensores Térmicos M4 y Metadatos
            RightPanelSensorsView(
                sensors: sensors,
                filterCategory: $filterCategory,
                selectedSensor: $selectedSensor
            )
            .frame(minWidth: 450)
        }
        .frame(minWidth: 800, minHeight: 580)
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
        
        // 1. Escanear sensores térmicos y metadatos IOKit / SMC
        let smcScanner = SMCScanner()
        let result = smcScanner.getDetailedSensors()
        self.sensors = result.sensors
        self.isConnected = result.connectionOk
        self.connectionStatus = result.connectionOk ? "Conectado (Sin Sandbox)" : "Error de Conexión"

        // 2. Escanear estado de ventiladores usando FanScanner dedicado
        let fanScanner = FanScanner()
        self.fans = fanScanner.getAllFans()
        
        isScanning = false
    }
}

/// Panel lateral izquierdo enfocado en el estado de conexión y lista de ventiladores
struct LeftPanelFansView: View {
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

            // Lista de Ventiladores
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

/// Panel principal derecho con la lista de sensores térmicos, filtros y badges
struct RightPanelSensorsView: View {
    let sensors: [SensorInfo]
    @Binding var filterCategory: SensorCategory?
    @Binding var selectedSensor: SensorInfo?

    var filteredSensors: [SensorInfo] {
        if let filter = filterCategory {
            return sensors.filter { $0.category == filter }
        }
        return sensors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Encabezado de la Sección de Sensores
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensores Térmicos M4")
                        .font(.title2)
                        .bold()
                    Text("Acceso IOKit directo sin restricciones de Sandbox")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(sensors.count) activos")
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top)

            // Selector de Filtros por Categoría
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: { filterCategory = nil }) {
                        Text("Todos (\(sensors.count))")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(filterCategory == nil ? Color.blue : Color.secondary.opacity(0.12))
                            .foregroundColor(filterCategory == nil ? .white : .primary)
                            .cornerRadius(8)
                    }

                    ForEach(SensorCategory.allCases, id: \.self) { cat in
                        let count = sensors.filter { $0.category == cat }.count
                        if count > 0 {
                            Button(action: { filterCategory = cat }) {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.iconName)
                                    Text("\(cat.rawValue) (\(count))")
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(filterCategory == cat ? Color.blue : Color.secondary.opacity(0.12))
                                .foregroundColor(filterCategory == cat ? .white : .primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Lista de Sensores Térmicos
            if !filteredSensors.isEmpty {
                List(filteredSensors, id: \.id) { sensor in
                    SensorRowView(sensor: sensor)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSensor = sensor
                        }
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
        }
    }
}

/// Fila individual para renderizar cada sensor térmico con su valor y metadatos rápidos
struct SensorRowView: View {
    let sensor: SensorInfo

    private var temperatureColor: Color {
        if sensor.value < 45 { return .green }
        if sensor.value < 65 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sensor.category.iconName)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(sensor.rawKey)
                    .font(.system(.body, design: .monospaced))
                    .bold()

                HStack(spacing: 6) {
                    Text(sensor.source.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(sensor.thermalZone ?? "PMU Zone")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f °C", sensor.value))
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                    .foregroundColor(temperatureColor)

                HStack(spacing: 2) {
                    Text("Metadatos")
                    Image(systemName: "info.circle")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
