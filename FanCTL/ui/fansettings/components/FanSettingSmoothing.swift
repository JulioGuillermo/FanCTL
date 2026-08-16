//
//  FanSettingSmoothing.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingSmoothing: View {
    @Binding var config: FanSettings
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack{
                Toggle(
                    "Speed smoothing",
                    isOn: $config.filterEnabled
                )
                .font(.headline)
                
                Spacer()
            }

            if config.filterEnabled {
                HStack(spacing: 10) {
                    Text("Fixed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(
                        value: $config.filterFactor,
                        in: 0...1,
                        step: 0.05
                    )
                    Text("Unfiltered")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(
                    String(
                        format:
                            "Speed = previous × %.0f%% + calculated × %.0f%%",
                        (1 - config.filterFactor) * 100,
                        config.filterFactor * 100
                    )
                )
                .font(.caption2)
                .foregroundColor(.secondary)

                if config.filterFactor < 0.01 {
                    Text(
                        "Fixed: the fan stays at its current speed."
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}
