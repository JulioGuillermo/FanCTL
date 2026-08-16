//
//  RightPannelView.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

struct RightPanelFansView: View {
    let fans: [FanInfo]
    let systemInfo: SystemInfo
    let isConnected: Bool
    let connectionStatus: String
    let controlActive: Bool
    let controlError: String?
    let isRequestingPermissions: Bool
    let modeFor: (FanInfo) -> FanMode
    let desiredRPMFor: (FanInfo) -> Double
    let manualRPMFor: (FanInfo) -> Double
    let minSpeedRPMFor: (FanInfo) -> Double
    let maxSpeedRPMFor: (FanInfo) -> Double
    let onChangeMode: (FanInfo, FanMode) -> Void
    let onManualRPMChange: (FanInfo, Double) -> Void
    let onGeneralSettings: () -> Void
    let onFanSettings: (FanInfo) -> Void
    let onRequestControl: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusIndicator(
                isConnected: isConnected,
                connectionStatus: connectionStatus,
                controlActive: controlActive
            )

            Divider()
            
            if !controlActive {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fan control disabled")
                            .font(.caption)
                            .bold()
                        Text(
                            "Background control requires administrator privileges."
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Start control") { onRequestControl() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                        .disabled(isRequestingPermissions)
                }
                .padding(10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 4)

                if let controlError {
                    Text(controlError)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }

                if isRequestingPermissions {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Requesting administrator privileges…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }

            // Fan list (takes all available space)
            if !fans.isEmpty {
                ScrollView {
                    // Group the glass cards so they blend as a single material
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(fans) { fan in
                                FanRowView(
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
                // State for fanless Macs (e.g. MacBook Air)
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

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                MacTypeInfo(systemInfo: systemInfo)
            }

            ToolbarItem(placement: .principal) {
                MacNameInfo(systemInfo: systemInfo)
            }

            // General settings at the trailing edge of the app bar
            ToolbarItem(placement: .primaryAction) {
                Button(action: onGeneralSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .help("General settings")
            }
        }
    }
}
