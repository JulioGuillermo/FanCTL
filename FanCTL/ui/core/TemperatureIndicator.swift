//
//  TemperatureIndicator.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

enum TemperatureIndicator {
    static func iconName(for temperature: Double) -> String {
        if temperature > 95 { return "flame" }
        if temperature > 70 { return "thermometer.high" }
        if temperature > 50 { return "thermometer.medium" }
        return "thermometer.low"
    }

    static func color(for temperature: Double) -> Color {
        if temperature > 95 { return .red }
        if temperature > 70 { return .red }
        if temperature > 50 { return .orange }
        return .green
    }
    
    static func tempColor(for temperature: Double) -> Color {
        let min = 50.0
        let max = 75.0
        return fluidColorG(forPercentage: (temperature - min) / (max - min))
    }

    static func spinSpeed(forPercentage percentage: Double) -> Double {
        1 + max(0, min(percentage, 1)) * 4
    }
    
    static func fluidColorG(forPercentage percentage: Double) -> Color {
        let p = max(0, min(percentage, 1))
        
        if p < 0.5 {
            let p = p * 2
            return Color(
                red: p,
                green: 1,
                blue: 0
            )
        } else {
            let p = (p - 0.5) * 2
            return Color(
                red: 1,
                green: 1 - p,
                blue: 0,
            )
        }
    }
    
    static func fluidColorB(forPercentage percentage: Double) -> Color {
        let p = max(0, min(percentage, 1))
        
        if p < 0.5 {
            let p = p * 2
            return Color(
                red: p,
                green: 0.7,
                blue: 1
            )
        } else {
            let p = (p - 0.5) * 2
            return Color(
                red: 1,
                green: 0.7,
                blue: 1 - p,
            )
        }
    }
}
