//
//  FanRowView.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 15/08/2026.
//


import SwiftUI

/// Componente de interfaz de usuario para mostrar un ventilador individual
struct FanRowView: View {
    let fan: FanInfo

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

            HStack {
                Text("Mín: \(Int(fan.minRPM))")
                
                Spacer()
                
                if let target = fan.targetRPM {
                    Text("Obj: \(Int(target)) RPM")
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
    .frame(width: 400)
}