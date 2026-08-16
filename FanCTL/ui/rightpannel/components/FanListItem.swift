//
//  FanListItem.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanListItem: View {
    let fan: FanInfo
    var mode: FanMode = .automatic
    var desiredRPM: Double? = nil
    var manualRPM: Double = 1500
    var minSpeedRPM: Double? = nil
    var maxSpeedRPM: Double? = nil
    var controlActive: Bool = false
    var isRequestingPermissions: Bool = false
    var onChangeMode: (FanMode) -> Void = { _ in }
    var onManualRPMChange: (Double) -> Void = { _ in }
    var onRequestControl: () -> Void = {}
    var onSettings: () -> Void = {}

    public var body: some View {
        VStack(spacing: 8) {
            FanMainInfo(fan: fan, onSettings: onSettings)

            SelectorLiquidGlass(
                mode: Binding(
                    get: { mode },
                    set: { onChangeMode($0) }
                ),
                onChange: onChangeMode
            )

            // Manual speed slider
            if mode == .manual {
                HStack(spacing: 10) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { manualRPM },
                            set: { onManualRPMChange($0) }
                        ),
                        in: (minSpeedRPM ?? fan.minRPM)...max(
                            (maxSpeedRPM ?? fan.maxRPM),
                            (minSpeedRPM ?? fan.minRPM)
                        ),
                        step: 50
                    )

                    Text("\(Int(manualRPM))")
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
            }

            FanPercentageIndicator(percentage: fan.percentage)

            // Speed being applied according to the mode
            if let desired = desiredRPM {
                HStack {
                    Label(
                        String(format: "Control: %d RPM", Int(desired)),
                        systemImage: mode.iconName
                    )
                    .bold()
                    .foregroundColor(controlActive ? .blue : .secondary)

                    Spacer()

                    if !controlActive {
                        if isRequestingPermissions {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Requesting permissions…")
                            }
                            .font(.caption2)
                        } else {
                            Button("Start control") { onRequestControl() }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                        }
                    }
                }
                .font(.caption2)
            }

            HStack {
                Text("Min: \(Int(fan.minRPM))")

                Spacer()

                if let target = fan.targetRPM {
                    Text("SMC target: \(Int(target)) RPM")
                        .foregroundColor(.blue)
                    Spacer()
                }

                Text("Max: \(Int(fan.maxRPM))")

                Spacer()

                Text(fan.percentageString)
                    .bold()
                    .foregroundColor(
                        TemperatureIndicator.fluidColorB(
                            forPercentage: fan.percentage
                        )
                    )
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    GlassPannelColor
                )
        )
        .glassEffect(
            .clear,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.50),
                            .white.opacity(0.15),
                            .black.opacity(0.30),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 5
                )
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        FanListItem(
            fan: FanInfo(
                id: 0,
                name: "Main Fan",
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

        FanListItem(
            fan: FanInfo(
                id: 1,
                name: "Secondary Fan (GPU)",
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
