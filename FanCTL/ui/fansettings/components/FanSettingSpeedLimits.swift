//
//  FanSettingSpeedLimits.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingSpeedLimits: View {
    let fan: FanInfo
    @State var config: FanSettings

    private var effMin: Double { config.minRPM ?? fan.minRPM }
    private var effMax: Double { config.maxRPM ?? fan.maxRPM }

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

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Limit speed range", isOn: isCustomRangeBinding)
                .font(.headline)

            if config.minRPM != nil || config.maxRPM != nil {
                speedRangeRow(
                    label: "Min speed (RPM)",
                    value: minRPMBinding
                )
                speedRangeRow(
                    label: "Max speed (RPM)",
                    value: maxRPMBinding
                )

                Text(
                    "Within the fan's real range: \(Int(fan.minRPM)) – \(Int(fan.maxRPM)) RPM. Useful to extend the fan's lifespan."
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
    }

    private func speedRangeRow(label: String, value: Binding<Double>)
        -> some View
    {
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

}
