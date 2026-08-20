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

            RootBanner(
                controlActive: controlActive,
                isRequestingPermissions: isRequestingPermissions,
                onRequestControl: onRequestControl,
                controlError: controlError
            )

            FanList(
                fans: fans,
                controlActive: controlActive,
                isRequestingPermissions: isRequestingPermissions,
                modeFor: modeFor,
                desiredRPMFor: desiredRPMFor,
                manualRPMFor: manualRPMFor,
                minSpeedRPMFor: minSpeedRPMFor,
                maxSpeedRPMFor: maxSpeedRPMFor,
                onChangeMode: onChangeMode,
                onManualRPMChange: onManualRPMChange,
                onFanSettings: onFanSettings,
                onRequestControl: onRequestControl
            )

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
