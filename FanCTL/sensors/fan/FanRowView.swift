import SwiftUI

/// Componente de interfaz de usuario para mostrar y controlar un ventilador.
struct FanRowView: View {
    let fan: FanInfo
    var mode: FanMode = .automatic
    var desiredRPM: Double? = nil
    var manualRPM: Double = 1500
    var controlActive: Bool = false
    var onChangeMode: (FanMode) -> Void = { _ in }
    var onManualRPMChange: (Double) -> Void = { _ in }
    var onRequestControl: () -> Void = {}
    var onSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "fanblades.fill")
                    .foregroundColor(fan.statusColor)
                    .font(.system(size: 16))

                Text(fan.name)
                    .bold()
                    .font(.body)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(fan.currentRPM))")
                        .font(.system(.title3, design: .monospaced))
                        .bold()
                        .foregroundColor(fan.statusColor)

                    Text("RPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Ajustes de \(fan.name)")
            }

            // Selector de modo de control (visible y directo)
            Picker("Modo", selection: Binding(
                get: { mode },
                set: { onChangeMode($0) }
            )) {
                ForEach(FanMode.allCases, id: \.self) { candidate in
                    Label(candidate.rawValue, systemImage: candidate.iconName)
                        .tag(candidate)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Slider de velocidad manual
            if mode == .manual {
                HStack(spacing: 10) {
                    Text("Velocidad")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { manualRPM },
                            set: { onManualRPMChange($0) }
                        ),
                        in: fan.minRPM...max(fan.minRPM, fan.maxRPM),
                        step: 50
                    )

                    Text("\(Int(manualRPM))")
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, fan.statusColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(fan.percentage), height: 8)
                }
            }
            .frame(height: 8)

            // Velocidad que se está aplicando según el modo
            if let desired = desiredRPM {
                HStack {
                    Label(String(format: "Control: %d RPM", Int(desired)), systemImage: mode.iconName)
                        .bold()
                        .foregroundColor(controlActive ? .blue : .secondary)

                    Spacer()

                    if !controlActive {
                        Button("Activar control") { onRequestControl() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .font(.caption2)
            }

            HStack {
                Text("Mín: \(Int(fan.minRPM))")
                
                Spacer()
                
                if let target = fan.targetRPM {
                    Text("Obj SMC: \(Int(target)) RPM")
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                Text("Máx: \(Int(fan.maxRPM))")
                
                Spacer()
                
                Text(fan.percentageString)
                    .bold()
                    .foregroundColor(fan.statusColor)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        FanRowView(
            fan: FanInfo(
                id: 0,
                name: "Ventilador Principal",
                currentRPM: 2450,
                minRPM: 1200,
                maxRPM: 6500,
                targetRPM: 2450,
                mode: .automatic
            ),
            mode: .automatic,
            desiredRPM: 4000,
            manualRPM: 3000,
            controlActive: true
        )
        
        FanRowView(
            fan: FanInfo(
                id: 1,
                name: "Ventilador Secundario (GPU)",
                currentRPM: 5100,
                minRPM: 1200,
                maxRPM: 6500,
                targetRPM: 5200,
                mode: .manual
            ),
            mode: .manual,
            desiredRPM: 3000,
            manualRPM: 3000,
            controlActive: true
        )
    }
    .padding()
    .frame(width: 480)
}
