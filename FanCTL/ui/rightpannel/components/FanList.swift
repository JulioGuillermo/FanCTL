//
//  FanList.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanList: View {
    let fans: [FanInfo]
    let controlActive: Bool
    let isRequestingPermissions: Bool
    let modeFor: (FanInfo) -> FanMode
    let desiredRPMFor: (FanInfo) -> Double
    let manualRPMFor: (FanInfo) -> Double
    let minSpeedRPMFor: (FanInfo) -> Double
    let maxSpeedRPMFor: (FanInfo) -> Double
    let onChangeMode: (FanInfo, FanMode) -> Void
    let onManualRPMChange: (FanInfo, Double) -> Void
    let onFanSettings: (FanInfo) -> Void
    let onRequestControl: () -> Void

    public var body: some View {
        if !fans.isEmpty {
            ScrollView {
                // Group the glass cards so they blend as a single material
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(fans) { fan in
                            FanListItem(
                                fan: fan,
                                mode: modeFor(fan),
                                desiredRPM: desiredRPMFor(fan),
                                manualRPM: manualRPMFor(fan),
                                minSpeedRPM: minSpeedRPMFor(fan),
                                maxSpeedRPM: maxSpeedRPMFor(fan),
                                controlActive: controlActive,
                                isRequestingPermissions:
                                    isRequestingPermissions,
                                onChangeMode: { onChangeMode(fan, $0) },
                                onManualRPMChange: {
                                    onManualRPMChange(fan, $0)
                                },
                                onRequestControl: onRequestControl,
                                onSettings: { onFanSettings(fan) }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "wind")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.6))
                Text("No fans")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(
                    "This machine uses passive cooling or does not report fans."
                )
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
