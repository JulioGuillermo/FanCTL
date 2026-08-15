import SwiftUI

/// Componente de interfaz de usuario para mostrar un ventilador individual
struct FanRowView: View {
    let fan: FanInfo
    var mode: FanMode = .automatic
    var desiredRPM: Double? = nil
    var controlActive: Bool = false
    var onChangeMode: (FanMode) -> Void = { _ in }
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

                // Selector rápido de modo
                Menu {
                    ForEach(FanMode.allCases, id: \.self) { candidate in
                        Button {
                            onChangeMode(candidate)
                        } label: {
                            Label(candidate.rawValue, systemImage: candidate.iconName)
                            if candidate == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                        Text(mode.rawValue)
                    }
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

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
                        Text("Requiere root")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.orange)
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
                mode: .automatic
            ),
            mode: .manual,
            desiredRPM: 3000,
            controlActive: false
        )
    }
    .padding()
    .frame(width: 420)
}
