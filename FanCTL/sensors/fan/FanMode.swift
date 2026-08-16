import Foundation

/// Fan operating/control mode.
enum FanMode: String, Codable, CaseIterable {
    case automatic = "Auto"
    case manual = "Manual"
    case off = "Off"
    case maximum = "Max"

    var iconName: String {
        switch self {
        case .automatic: return "wand.and.rays"
        case .manual: return "slider.horizontal.3"
        case .off: return "power"
        case .maximum: return "gauge.high"
        }
    }
}
