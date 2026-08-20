import SwiftUI

/// Helper for the max temperature indicator: selects the icon and
/// color according to the measured value.

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
