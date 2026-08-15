import Foundation
internal import Combine

/// Controla la velocidad real de los ventiladores escribiendo al AppleSMC.
///
/// El protocolo de control es el clásico: en modo manual (`F{i}Md = 1`) el
/// firmware fija el ventilador a la velocidad de `F{i}Mn`. Escribir en el SMC
/// requiere privilegios de root (sin ellos `IOConnectCallStructMethod` devuelve
/// `kIOReturnNotPrivileged`), por lo que este controlador detecta y expone esa
/// situación.
final class FanController: ObservableObject {
    private let client: SMCClient
    @Published private(set) var canControlHardware = false
    private var privilegeChecked = false
    private var lastApplied: [Int: Double] = [:]

    init(client: SMCClient = SMCClient()) {
        self.client = client
    }

    /// Comprueba si el proceso puede escribir en el SMC (requiere root).
    /// Usa una escritura inocua (F0Md = 0, modo auto) y cachea el resultado.
    @discardableResult
    func checkPrivileges() -> Bool {
        if privilegeChecked { return canControlHardware }
        privilegeChecked = true
        guard client.open() else { return false }
        defer { client.close() }
        canControlHardware = client.writeKeyData("F0Md", bytes: [0])
        if !canControlHardware {
            AppLog.log("[FanController] Sin privilegios: las escrituras al SMC requieren root.")
        }
        return canControlHardware
    }

    /// Fija la velocidad de un ventilador dejándolo en modo manual.
    /// Omite la escritura si la velocidad no ha cambiado desde la última vez.
    func setSpeed(_ rpm: Double, toFan index: Int) {
        guard canControlHardware || checkPrivileges() else { return }
        if lastApplied[index] == rpm { return }

        guard client.open() else { return }
        defer { client.close() }

        let key = "F\(index)"
        let fltBytes = withUnsafeBytes(of: Float(rpm)) { Array($0) }

        if client.writeKeyData(key + "Md", bytes: [1]) {
            lastApplied[index] = rpm
            AppLog.log("[FanController] F\(index) manual, velocidad = \(Int(rpm)) RPM")
        }
        client.writeKeyData(key + "Mn", bytes: fltBytes)
    }

    /// Devuelve el control del ventilador al sistema (modo automático).
    func restoreSystemControl(toFan index: Int) {
        guard client.open() else { return }
        defer { client.close() }
        let key = "F\(index)"
        if client.writeKeyData(key + "Md", bytes: [0]) {
            lastApplied.removeValue(forKey: index)
            AppLog.log("[FanController] F\(index) restaurado al control del sistema")
        }
    }
}
