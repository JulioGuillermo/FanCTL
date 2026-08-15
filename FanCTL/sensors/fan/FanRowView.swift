import SwiftUI

/// Componente de interfaz de usuario para mostrar un ventilador individual
struct FanRowView: View {
    let fan: FanInfo
    var calculation: FanSpeedCalculation? = nil
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

            // Resumen del control calculado a partir de los sensores seleccionados
            if let calc = calculation, let maxTemp = calc.maxSelectedTemperature, let target = calc.targetRPM {
                HStack {
                    Label(String(format: "Máx: %.1f °C", maxTemp), systemImage: "thermometer")
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Control: \(Int(target)) RPM")
                        .bold()
                        .foregroundColor(.blue)

                    Spacer()

                    Text(String(format: "%.0f%%", calc.normalizedValue * 100))
                        .bold()
                        .foregroundColor(.secondary)
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
        FanRowView(fan: FanInfo(
            id: 0,
            name: "Ventilador Principal",
            currentRPM: 2450,
            minRPM: 1200,
            maxRPM: 6500,
            targetRPM: 2450,
            mode: .automatic
        ), calculation: FanSpeedCalculation(
            maxSelectedTemperature: 62.0,
            normalizedValue: 0.53,
            targetRPM: 4000
        ))
        
        FanRowView(fan: FanInfo(
            id: 1,
            name: "Ventilador Secundario (GPU)",
            currentRPM: 5100,
            minRPM: 1200,
            maxRPM: 6500,
            targetRPM: 5200,
            mode: .automatic
        ))
    }
    .padding()
    .frame(width: 420)
}
