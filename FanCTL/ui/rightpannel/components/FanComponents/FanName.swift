//
//  FanName.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanName: View {
    let fan: FanInfo

    public var body: some View {
        HStack {
            SpinningFanIcon(
                id: String(fan.id),
                percentage: fan.percentage
            )
            .foregroundColor(
                TemperatureIndicator.fluidColorB(
                    forPercentage: fan.percentage
                )
            )
            .font(.system(size: 16))

            Text(fan.name)
                .bold()
                .font(.body)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        FanName(
            fan: .init(
                id: 0,
                name: "Fan 1",
                currentRPM: 1000,
                minRPM: 0,
                maxRPM: 1000,
                targetRPM: 500,
                mode: .automatic
            )
        )
        FanName(
            fan: .init(
                id: 1,
                name: "Fan 2",
                currentRPM: 1000,
                minRPM: 0,
                maxRPM: 2000,
                targetRPM: 400,
                mode: .automatic
            )
        )
        FanName(
            fan: .init(
                id: 2,
                name: "Fan 3",
                currentRPM: 1000,
                minRPM: 500,
                maxRPM: 3000,
                targetRPM: 200,
                mode: .automatic
            )
        )
        FanName(
            fan: .init(
                id: 3,
                name: "Fan 4",
                currentRPM: 1000,
                minRPM: 1000,
                maxRPM: 4000,
                targetRPM: 100,
                mode: .automatic
            )
        )
    }
    .padding(20)
}
