//
//  FanSettingManualSpeedSection.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingManualSpeedSection: View {
    let fan: FanInfo
    let effMin: Double
    let effMax: Double
    @Binding var config: FanSettings

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Fixed speed")
                    .foregroundColor(.secondary)

                Spacer()

                TextField(
                    "RPM",
                    value: Binding(
                        get: { config.manualRPM },
                        set: { config.manualRPM = min(max($0, effMin), effMax) }
                    ),
                    format: .number
                )
                .textFieldStyle(.plain)
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

            Text(
                "Range: \(Int(effMin)) – \(Int(effMax)) RPM (fan's real range: \(Int(fan.minRPM)) – \(Int(fan.maxRPM)))"
            )
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(10)
    }
}
