import SwiftUI

/// Model structure with all metrics of a fan.
struct FanInfo: Identifiable, Hashable, Codable {
    let id: Int               // Fan index (0, 1, 2...)
    let name: String          // Human-readable name (e.g. "Main Fan")
    let currentRPM: Double    // Current measured speed in RPM
    let minRPM: Double        // Minimum speed allowed by the firmware
    let maxRPM: Double        // Maximum speed allowed by the firmware
    let targetRPM: Double?    // Target speed set by macOS
    let mode: FanMode         // Current operating mode

    /// Relative percentage of the current speed within the range (0.0 to 1.0)
    var percentage: Double {
        let totalRange = max(1.0, maxRPM - minRPM)
        let currentProgress = (currentRPM - minRPM) / totalRange
        return min(1.0, max(0.0, currentProgress))
    }

    /// Formatted percentage for display (0 - 100%)
    var percentageString: String {
        return String(format: "%.0f%%", percentage * 100.0)
    }

    /// Suggested visual thermal status based on RPMs
    var statusColor: Color {
        if currentRPM <= minRPM + 200 {
            return .blue      // Idle / quiet
        } else if currentRPM < (maxRPM * 0.75) {
            return .orange    // Moderate load
        } else {
            return .red       // High load / maximum performance
        }
    }
}
