//
//  FanSettingSummary.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

struct FanSettingSummary: View {
    let fan: FanInfo
    let config: FanSettings
    let sensors: [SensorInfo]
    let temperatureSensors: [SensorInfo]
    let effMin: Double
    let effMax: Double

    private var calculation: FanSpeedCalculation {
        FanSpeedCalculation.compute(fan: fan, config: config, sensors: sensors)
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

    private var selectedCount: Int {
        temperatureSensors.filter { config.selectedSensorKeys.contains($0.id) }
            .count
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if config.mode == .automatic {
                    Text(
                        "Sensors: \(selectedCount)/\(temperatureSensors.count)"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    if let maxTemp = calculation.maxSelectedTemperature {
                        Text(String(format: "Max: %.1f °C", maxTemp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Mode: \(config.mode.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if config.mode == .automatic {
                    Text(
                        String(
                            format: "Normalized: %.0f%%",
                            calculation.normalizedValue * 100
                        )
                    )
                    .font(.caption)
                    .bold()
                }
                if let target = summaryTargetRPM {
                    Text("Target speed: \(Int(target)) RPM")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
    }
}
