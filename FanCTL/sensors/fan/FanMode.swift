import Foundation

/// Modo de funcionamiento o control del ventilador.
enum FanMode: String, Codable, CaseIterable {
    case automatic = "Automático (Sistema)"
    case manual = "Manual (Personalizado)"

    var iconName: String {
        switch self {
        case .automatic: return "gearshape.2.fill"
        case .manual: return "slider.horizontal.3"
        }
    }
}
