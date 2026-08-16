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

    /// Color gradient as a function of the fan speed percentage (0...1):
    /// green at low speed, orange in the middle, red at full speed.
    static func speedColor(forPercentage percentage: Double) -> Color {
        let p = max(0, min(percentage, 1))
        let stops: [(pos: Double, r: Double, g: Double, b: Double)] = [
            (0.0, 0.22, 0.80, 0.35),
            (0.4, 0.95, 0.62, 0.08),
            (0.7, 0.95, 0.25, 0.20),
        ]
        for i in 0..<(stops.count - 1) {
            let a = stops[i]
            let b = stops[i + 1]
            if p <= b.pos {
                let t = (p - a.pos) / max(b.pos - a.pos, 1e-9)
                return Color(red: a.r + (b.r - a.r) * t,
                             green: a.g + (b.g - a.g) * t,
                             blue: a.b + (b.b - a.b) * t)
            }
        }
        let last = stops[stops.count - 1]
        return Color(red: last.r, green: last.g, blue: last.b)
    }
}

/// Mutable state of a fan animation, kept across frames without triggering
/// SwiftUI invalidations (TimelineView drives the frames by itself).
///
/// The spinner state lives in a STATIC registry keyed by `id` (not in
/// `@State`): a parent re-render can rebuild the view struct, and relying on
/// `@State` would reset the accumulated angle on every refresh, breaking the
/// animation. The registry survives rebuilds and guarantees continuity.
final class FanSpinner {
    var angle: Double = 0
    var lastDate: Date?
    var currentRevsPerSec: Double = 1

    private static var spinners: [String: FanSpinner] = [:]

    /// Returns the spinner that persists for the given `id`. Shared between
    /// the SwiftUI fan icon and the menu bar indicator so both rotate
    /// continuously.
    static func shared(for id: String) -> FanSpinner {
        if spinners[id] == nil {
            spinners[id] = FanSpinner()
        }
        return spinners[id]!
    }

    /// Advances the rotation using the accumulated-angle model (never jumps).
    /// Eases the angular speed toward `targetRevs` (≈0.5s time constant) so
    /// RPM changes from periodic refreshes glide into each other instead of
    /// snapping the rotation speed at each update.
    /// - Returns: the current rotation angle in degrees.
    func advance(to targetRevs: Double, at now: Date) -> Double {
        if let last = lastDate {
            // Clamp dt so a long pause (e.g. app in background) cannot
            // produce a giant angle jump on the next frame.
            let dt = max(0, min(now.timeIntervalSince(last), 0.1))
            if dt > 0 {
                let ease = 1 - exp(-2 * dt)
                currentRevsPerSec += (targetRevs - currentRevsPerSec) * ease
                angle = (angle + dt * currentRevsPerSec * 360)
                    .truncatingRemainder(dividingBy: 360)
            }
        }
        lastDate = now
        return angle
    }
}

/// Animated fan icon: spins at a speed proportional to the percentage.
///
/// The rotation angle is ACCUMULATED frame by frame (angle += speed × dt)
/// instead of being derived from absolute time, so an update of the
/// percentage changes only the rotation speed and never resets or jumps
/// the icon.
struct SpinningFanIcon: View {
    var id: String = "fan"
    var percentage: Double = 1

    var body: some View {
        TimelineView(.animation) { context in
            let angle = FanSpinner.shared(for: id).advance(
                to: TemperatureIndicator.spinSpeed(forPercentage: percentage),
                at: context.date
            )
            return Image(systemName: "fanblades.fill")
                .rotationEffect(.degrees(angle))
        }
    }
}
