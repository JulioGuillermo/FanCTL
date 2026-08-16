import SwiftUI

/// Helper for the max temperature indicator: selects the icon and
/// color according to the measured value.
enum TemperatureIndicator {
    /// Icon according to the temperature tier: <50 low, 50-70 medium,
    /// 70-95 high and >95 critical (flame).
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

    /// Spin speed (revolutions/s) of a fan according to its percentage (0...1).
    /// Minimum 1 revolution/s at 0% and maximum 5 at 100%.
    static func spinSpeed(forPercentage percentage: Double) -> Double {
        1 + max(0, min(percentage, 1)) * 4
    }
}

/// Animated fan icon: spins at a speed proportional to the percentage.
struct SpinningFanIcon: View {
    var percentage: Double = 1

    var body: some View {
        TimelineView(.animation) { context in
            let revsPerSec = TemperatureIndicator.spinSpeed(forPercentage: percentage)
            let degrees = (context.date.timeIntervalSinceReferenceDate * revsPerSec * 360)
                .truncatingRemainder(dividingBy: 360)
            Image(systemName: "fanblades.fill")
                .rotationEffect(.degrees(degrees))
        }
    }
}
