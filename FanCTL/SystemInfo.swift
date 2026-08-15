import Foundation
import SystemConfiguration

/// Tipo de equipo Mac detectado desde el identificador del modelo.
enum MacType: String {
    case macMini = "Mac mini"
    case macStudio = "Mac Studio"
    case macBookPro = "MacBook Pro"
    case macBookAir = "MacBook Air"
    case macBook = "MacBook"
    case iMac = "iMac"
    case macPro = "Mac Pro"
    case unknown = "Mac"

    /// Símbolo SF apropiado para cada tipo de equipo.
    var iconName: String {
        switch self {
        case .macMini: return "macmini.fill"
        case .macStudio: return "macstudio.fill"
        case .macBookPro, .macBookAir, .macBook: return "laptopcomputer"
        case .iMac, .macPro, .unknown: return "desktopcomputer"
        }
    }
}

/// Información del equipo detectada del sistema (no hardcodeada).
struct SystemInfo {
    /// Nombre visible del equipo (el que el usuario ve en Ajustes del Sistema).
    let computerName: String
    /// Tipo de Mac (Mac mini, MacBook Pro, Mac Studio, etc.).
    let type: MacType
    /// Identificador de hardware (ej. "Mac15,12").
    let modelIdentifier: String

    /// Instancia única cacheada (la info no cambia en caliente).
    static let shared = SystemInfo.current()

    static func current() -> SystemInfo {
        let identifier = hardwareModelIdentifier()
        return SystemInfo(
            computerName: computerName(),
            type: macType(for: identifier),
            modelIdentifier: identifier
        )
    }

    /// Identificador de hardware vía `sysctl` ("hw.model").
    private static func hardwareModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Desconocido" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    /// Nombre del equipo desde SystemConfiguration.
    private static func computerName() -> String {
        guard let name = SCDynamicStoreCopyComputerName(nil, nil) else { return "Mac" }
        return name as String
    }

    /// Deriva el tipo de Mac a partir del identificador de hardware.
    /// 1º busca en la tabla de modelos Apple Silicon ("MacN,M"), 2º parsea el
    /// prefijo de los modelos Intel ("MacBookPro*", "Macmini*", etc.).
    private static func macType(for identifier: String) -> MacType {
        if let known = appleSiliconModels[identifier] {
            return known
        }
        if identifier.hasPrefix("MacBookPro") { return .macBookPro }
        if identifier.hasPrefix("MacBookAir") { return .macBookAir }
        if identifier.hasPrefix("MacBook") { return .macBook }
        if identifier.hasPrefix("Macmini") { return .macMini }
        if identifier.hasPrefix("MacStudio") { return .macStudio }
        if identifier.hasPrefix("MacPro") { return .macPro }
        if identifier.hasPrefix("iMac") { return .iMac }
        return .unknown
    }

    /// Tabla de identificadores Apple Silicon conocidos (los identificadores
    /// "MacN,M" no codifican el tipo en el nombre, así que hay que mapearlos).
    private static let appleSiliconModels: [String: MacType] = [
        // Mac mini
        "Macmini9,1": .macMini, // M1 (2020)
        "Mac14,3": .macMini,    // M2 (2023)
        "Mac14,12": .macMini,   // M2 Pro (2023)
        "Mac16,10": .macMini,   // M4 (2024)
        "Mac16,11": .macMini,   // M4 Pro (2024)

        // MacBook Air
        "MacBookAir10,1": .macBookAir, // M1 (2020)
        "Mac14,2": .macBookAir,        // M2 (2022)
        "Mac15,2": .macBookAir,        // M3 15" (2023)
        "Mac15,13": .macBookAir,       // M3 13" (2024)

        // MacBook Pro
        "MacBookPro17,1": .macBookPro, // M1 13" (2020)
        "MacBookPro18,1": .macBookPro, // M1 Pro 14" (2021)
        "MacBookPro18,2": .macBookPro, // M1 Max 14" (2021)
        "MacBookPro18,3": .macBookPro, // M1 Pro 16" (2021)
        "MacBookPro18,4": .macBookPro, // M1 Max 16" (2021)
        "MacBookPro14,1": .macBookPro, // M2 13" (2022)
        "MacBookPro14,2": .macBookPro, // M2 13" (2022)
        "Mac14,5": .macBookPro,        // M2 Pro 14" (2023)
        "Mac14,6": .macBookPro,        // M2 Pro 16" (2023)
        "Mac14,7": .macBookPro,        // M2 Max 14" (2023)
        "Mac14,9": .macBookPro,        // M2 Max 16" (2023)
        "Mac14,10": .macBookPro,       // M2 Pro 14" (2023)
        "Mac15,6": .macBookPro,        // M3 Pro 14" (2023)
        "Mac15,7": .macBookPro,        // M3 Pro 16" (2023)
        "Mac15,8": .macBookPro,        // M3 Max 14" (2023)
        "Mac15,9": .macBookPro,        // M3 Max 16" (2023)
        "Mac15,10": .macBookPro,       // M3 14" (2023)
        "Mac15,11": .macBookPro,       // M3 14" (2023)
        "Mac16,1": .macBookPro,        // M4 14" (2024)
        "Mac16,2": .macBookPro,        // M4 14" (2024)
        "Mac16,3": .macBookPro,        // M4 Pro 14" (2024)
        "Mac16,4": .macBookPro,        // M4 Pro 16" (2024)
        "Mac16,5": .macBookPro,        // M4 Max 14" (2024)
        "Mac16,6": .macBookPro,        // M4 Max 16" (2024)
        "Mac16,7": .macBookPro,        // M4 14" (2024)

        // Mac Studio
        "Mac13,1": .macStudio,  // M1 Max (2022)
        "Mac13,2": .macStudio,  // M1 Ultra (2022)
        "Mac14,13": .macStudio, // M2 Max (2023)
        "Mac14,14": .macStudio, // M2 Ultra (2023)
        "Mac16,15": .macStudio, // M4 Max (2025)
        "Mac16,16": .macStudio, // M4 Ultra (2025)

        // Mac Pro
        "Mac14,8": .macPro,     // M2 Ultra (2023)

        // iMac
        "iMac21,1": .iMac,      // M1 24" (2021)
        "iMac21,2": .iMac,      // M1 24" (2021)
        "Mac15,4": .iMac,       // M3 24" (2023)
        "Mac15,5": .iMac,       // M3 24" (2023)
        "Mac16,12": .iMac,      // M4 24" (2024)
        "Mac16,13": .iMac       // M4 24" (2024)
    ]
}
