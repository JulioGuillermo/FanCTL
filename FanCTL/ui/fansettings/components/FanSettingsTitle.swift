//
//  Title.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingsTitle: View {
    let fan: FanInfo
    let onClose: () -> Void

    public var body: some View {
        HStack(alignment: .top) {
            CloseButton(action: onClose)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fan settings")
                    .font(.title2)
                    .bold()
                Text(fan.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            SpinningFanIcon(
                id: String(fan.id),
                percentage: fan.percentage
            )
            .foregroundColor(.blue)
            .font(.title)
        }
    }
}
