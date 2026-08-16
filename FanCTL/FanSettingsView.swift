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

            // Modo de control
            VStack(alignment: .leading, spacing: 8) {
                Text("Modo de control")
                    .font(.headline)

                Picker("Modo", selection: $config.mode) {
                    ForEach(FanMode.allCases, id: \.self) { candidate in
                        Label(candidate.rawValue, systemImage: candidate.iconName)
                            .tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch config.mode {
                case .automatic:
                    Text("Velocidad calculada a partir de la temperatura máxima de los sensores seleccionados.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .manual:
                    manualSpeedSection
                        .padding(.top, 4)
                case .off:
                    Text("Ventilador fijado a la velocidad mínima (los ventiladores no pueden apagarse del todo).")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .maximum:
                    Text("Ventilador fijado a la velocidad máxima.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Rango de velocidad configurable (aplica a todos los modos)
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Limitar rango de velocidad", isOn: isCustomRangeBinding)
                    .font(.headline)

                if config.minRPM != nil || config.maxRPM != nil {
                    speedRangeRow(label: "Vel. mínima (RPM)", value: minRPMBinding)
                    speedRangeRow(label: "Vel. máxima (RPM)", value: maxRPMBinding)

                    Text("Dentro del rango real del ventilador: \(Int(fan.minRPM)) – \(Int(fan.maxRPM)) RPM. Útil para alargar la vida del ventilador.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Rango de temperatura a mantener (solo aplica en modo Auto)
            if config.mode == .automatic {
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
                        .frame(minHeight: 240, maxHeight: 320)
                        .clipped()
                    } else {
                        Text("Sin sensores detectados.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Resumen del cálculo
            summarySection
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            // Por defecto, si no hay selección guardada, seleccionar todos los sensores
            if config.selectedSensorKeys.isEmpty && !sensors.isEmpty {
                config.selectedSensorKeys = sensors.map(\.id)
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
                Text("Velocidad fija")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("RPM", value: Binding(
                    get: { config.manualRPM },
                    set: { config.manualRPM = min(max($0, effMin), effMax) }
                ), format: .number)
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

            Text("Rango: \(Int(effMin)) – \(Int(effMax)) RPM (real del ventilador: \(Int(fan.minRPM)) – \(Int(fan.maxRPM)))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var summarySection: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if config.mode == .automatic {
                    Text("Sensores: \(selectedCount)/\(sensors.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let maxTemp = calculation.maxSelectedTemperature {
                        Text(String(format: "Máx: %.1f °C", maxTemp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Modo: \(config.mode.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if config.mode == .automatic {
                    Text(String(format: "Normalizado: %.0f%%", calculation.normalizedValue * 100))
                        .font(.caption)
                        .bold()
                }
                if let target = summaryTargetRPM {
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

    private var isCustomRangeBinding: Binding<Bool> {
        Binding(
            get: { config.minRPM != nil || config.maxRPM != nil },
            set: { enabled in
                if enabled {
                    if config.minRPM == nil { config.minRPM = fan.minRPM }
                    if config.maxRPM == nil { config.maxRPM = fan.maxRPM }
                } else {
                    config.minRPM = nil
                    config.maxRPM = nil
                }
            }
        )
    }

    private var minRPMBinding: Binding<Double> {
        Binding(
            get: { config.minRPM ?? fan.minRPM },
            set: { config.minRPM = min(max($0, fan.minRPM), effMax - 50) }
        )
    }

    private var maxRPMBinding: Binding<Double> {
        Binding(
            get: { config.maxRPM ?? fan.maxRPM },
            set: { config.maxRPM = max(min($0, fan.maxRPM), effMin + 50) }
        )
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

    private func speedRangeRow(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
            Stepper("", value: value, in: 0...10000, step: 50)
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

            Text(SensorDescriptions.shortName(for: sensor.rawKey))
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Text(String(format: "%.1f °C", sensor.value))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .help(sensor.descriptionText)
        .padding(.vertical, 2)
    }
}
