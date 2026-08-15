import SwiftUI

/// Hoja de configuración de un ventilador: rango de temperatura a mantener
/// y selección de qué sensores lo controlan.
struct FanSettingsView: View {
    let fan: FanInfo
    let sensors: [SensorInfo]
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) var dismiss

    @State private var config: FanSettings

    init(fan: FanInfo, sensors: [SensorInfo], store: SettingsStore) {
        self.fan = fan
        self.sensors = sensors
        self.store = store
        _config = State(initialValue: store.fanSettings(for: fan))
    }

    private var calculation: FanSpeedCalculation {
        FanSpeedCalculation.compute(fan: fan, config: config, sensors: sensors)
    }

    private var selectedCount: Int {
        sensors.filter { config.selectedSensorKeys.contains($0.id) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "fanblades.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ajustes del ventilador")
                        .font(.title2)
                        .bold()
                    Text(fan.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cerrar") { dismiss() }
            }

            Divider()

            // Rango de temperatura a mantener
            VStack(alignment: .leading, spacing: 8) {
                Text("Temperaturas a mantener")
                    .font(.headline)

                temperatureRow(label: "Temp máxima (°C)", value: $config.maxTemperature)
                temperatureRow(label: "Temp mínima (°C)", value: $config.minTemperature)

                Text("Por debajo de la mínima la velocidad es mínima; por encima de la máxima, máxima.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Sensores que controlan este ventilador
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensores que controlan este ventilador")
                        .font(.headline)
                    Spacer()
                    Button("Todo") { selectAll() }
                    Button("Ninguno") { config.selectedSensorKeys = [] }
                }
                .font(.caption)

                if !sensors.isEmpty {
                    List(sensors, id: \.id) { sensor in
                        SensorSelectionRow(
                            sensor: sensor,
                            isSelected: config.selectedSensorKeys.contains(sensor.id),
                            onToggle: { toggle(sensor) }
                        )
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 280)
                } else {
                    Text("Sin sensores detectados.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Resumen del cálculo
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensores: \(selectedCount)/\(sensors.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let maxTemp = calculation.maxSelectedTemperature {
                        Text(String(format: "Máx: %.1f °C", maxTemp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "Normalizado: %.0f%%", calculation.normalizedValue * 100))
                        .font(.caption)
                        .bold()
                    if let target = calculation.targetRPM {
                        Text("Velocidad objetivo: \(Int(target)) RPM")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
        }
        .padding()
        .frame(width: 500, height: 640)
        .onAppear {
            // Por defecto, si no hay selección guardada, seleccionar todos los sensores
            if config.selectedSensorKeys.isEmpty && !sensors.isEmpty {
                config.selectedSensorKeys = sensors.map(\.id)
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

    private func temperatureRow(label: String, value: Binding<Double>) -> some View {
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

    private func selectAll() {
        config.selectedSensorKeys = sensors.map(\.id)
    }
}

/// Fila con checkbox para la selección de sensores dentro de la config de un fan.
private struct SensorSelectionRow: View {
    let sensor: SensorInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            Text(sensor.rawKey)
                .font(.system(.body, design: .monospaced))
                .bold()
                .strikethrough(!isSelected, color: .secondary)

            Spacer()

            Text(String(format: "%.1f °C", sensor.value))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
