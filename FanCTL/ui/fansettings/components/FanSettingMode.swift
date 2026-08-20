//
//  FanSettingMode.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingMode: View {
    @Binding var mode: FanMode

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Control mode")
                .font(.headline)

            SelectorLiquidGlass(
                mode: $mode,
                onChange: { mode in
                    self.mode = mode
                }
            )

            switch mode {
            case .automatic:
                Text(
                    "Speed calculated from the maximum temperature of the selected sensors."
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            case .manual:
                Text(
                    "Fan speed is set manually. Use the slider to adjust the speed."
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            case .off:
                Text(
                    "Fan fixed to the minimum speed (fans cannot be fully turned off)."
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            case .maximum:
                Text("Fan fixed to the maximum speed.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
    }
}
