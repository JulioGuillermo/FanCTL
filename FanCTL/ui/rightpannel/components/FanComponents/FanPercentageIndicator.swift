//
//  FanPercentageIndicator.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanPercentageIndicator: View {
    let percentage: Double
    
    public var body: some View{
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, TemperatureIndicator.fluidColorB(forPercentage: percentage)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * CGFloat(percentage),
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    FanPercentageIndicator(percentage: 0.1)
    FanPercentageIndicator(percentage: 0.5)
    FanPercentageIndicator(percentage: 1.0)
}
