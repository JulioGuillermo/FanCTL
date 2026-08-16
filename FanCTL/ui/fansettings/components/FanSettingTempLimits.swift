//
//  FanSettingTempLimits.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingTempLimits: View {
    let config: Binding<FanSettings>

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperatures to maintain")
                .font(.headline)

            temperatureRow(
                label: "Max temperature (°C)",
                value: config.maxTemperature
            )
            temperatureRow(
                label: "Min temperature (°C)",
                value: config.minTemperature
            )

            Text(
                "Below the minimum the speed is minimal; above the maximum, maximal."
            )
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(10)
    }

    private func temperatureRow(label: String, value: Binding<Double>)
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
            Stepper("", value: value, in: 0...150, step: 1)
                .labelsHidden()
        }
    }

}
