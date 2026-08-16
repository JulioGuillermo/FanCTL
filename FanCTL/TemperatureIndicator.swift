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

/// Mutable state of the fan animation, kept across frames without triggering
/// SwiftUI invalidations (TimelineView drives the frames by itself).
private final class FanSpinner {
    var angle: Double = 0
    var lastDate: Date?
    var currentRevsPerSec: Double = 1
}

/// Animated fan icon: spins at a speed proportional to the percentage.
///
/// The rotation angle is ACCUMULATED frame by frame (angle += speed × dt)
/// instead of being derived from absolute time, so an update of the
/// percentage changes only the rotation speed and never resets or jumps
/// the icon.
///
/// The spinner state lives in a STATIC dictionary keyed by `id` (not in
/// `@State`): a parent re-render can rebuild the view struct, and relying on
/// `@State` would reset the accumulated angle on every refresh, breaking the
/// animation. The dictionary survives rebuilds and guarantees continuity.
struct SpinningFanIcon: View {
    var id: String = "fan"
    var percentage: Double = 1

    private static var spinners: [String: FanSpinner] = [:]

    private var spinner: FanSpinner {
        if Self.spinners[id] == nil {
            Self.spinners[id] = FanSpinner()
        }
        return Self.spinners[id]!
    }

    var body: some View {
        TimelineView(.animation) { context in
            let now = context.date
            let targetRevs = TemperatureIndicator.spinSpeed(forPercentage: percentage)
            let state = spinner

            if let last = state.lastDate {
                // Clamp dt so a long pause (e.g. app in background) cannot
                // produce a giant angle jump on the next frame.
                let dt = max(0, min(now.timeIntervalSince(last), 0.1))
                if dt > 0 {
                    // Ease the angular speed toward the target. The constant is
                    // gentle (≈0.5s time constant) so RPM changes coming from
                    // periodic refreshes glide into each other instead of
                    // snapping the rotation speed at each update.
                    let ease = 1 - exp(-2 * dt)
                    state.currentRevsPerSec += (targetRevs - state.currentRevsPerSec) * ease
                    state.angle = (state.angle + dt * state.currentRevsPerSec * 360)
                        .truncatingRemainder(dividingBy: 360)
                }
            }
            state.lastDate = now

            return Image(systemName: "fanblades.fill")
                .rotationEffect(.degrees(state.angle))
        }
    }
}
