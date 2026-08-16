//
//  FanMainInfo.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanMainInfo: View {
    let fan: FanInfo
    var onSettings: () -> Void = {}

    public var body: some View {
        HStack {
            FanName(fan: fan)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(fan.currentRPM))")
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                    .foregroundColor(
                        TemperatureIndicator.fluidColorB(
                            forPercentage: fan.percentage
                        )
                    )

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
            .help("Settings for \(fan.name)")
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        FanMainInfo(
            fan: FanInfo(
                id: 0,
                name: "Fan 1",
                currentRPM: 1000,
                minRPM: 0,
                maxRPM: 1000,
                targetRPM: 500,
                mode: .automatic
            )
        )
        FanMainInfo(
            fan: FanInfo(
                id: 3,
                name: "Fan 4",
                currentRPM: 1000,
                minRPM: 1000,
                maxRPM: 4000,
                targetRPM: 100,
                mode: .automatic
            )
        )
    }
}
