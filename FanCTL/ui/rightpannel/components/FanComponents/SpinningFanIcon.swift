//
//  SpinningFanIcon.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct SpinningFanIcon: View {
    var id: String = "fan"
    var percentage: Double = 1

    public var body: some View {
        TimelineView(.animation) { context in
            let angle =
                FanSpinner
                .shared(for: id)
                .advance(
                    to: TemperatureIndicator.spinSpeed(
                        forPercentage: percentage
                    ),
                    at: context.date
                )
            return Image(systemName: "fanblades.fill")
                .rotationEffect(.degrees(angle))
        }
    }
}
