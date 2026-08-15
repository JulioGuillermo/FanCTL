import Foundation
internal import Combine

/// Controla la velocidad real de los ventiladores escribiendo al AppleSMC.
///
/// El protocolo de control es el clásico: en modo manual (`F{i}Md = 1`) el
/// firmware fija el ventilador a la velocidad de `F{i}Mn`. Escribir en el SMC
/// requiere privilegios de root (sin ellos `IOConnectCallStructMethod` devuelve
/// `kIOReturnNotPrivileged`), por lo que este controlador detecta y expone esa
/// situación.
///
/// Cuando el daemon privilegiado está disponible (`FanDaemonClient.isAvailable`)
/// el control se delega a él vía XPC; si no, se intenta la escritura directa.
final class FanController: ObservableObject {
    private let client: SMCClient
    private let daemon: FanDaemonClient?
    @Published private(set) var canControlHardware = false
    private var privilegeChecked = false
    private var lastApplied: [Int: Double] = [:]

    init(client: SMCClient = SMCClient(), daemon: FanDaemonClient? = nil) {
        self.client = client
        self.daemon = daemon
    }

    /// Comprueba si se puede escribir en el SMC. Si el daemon responde, ya hay
    /// control; si no, prueba una escritura inocua (F0Md = 0, modo auto).
    /// Cachea el resultado.
    @discardableResult
    func checkPrivileges() -> Bool {
        if privilegeChecked { return canControlHardware }
        privilegeChecked = true

        if let daemon, daemon.isAvailable {
            canControlHardware = true
            AppLog.log("[FanController] Control a través del daemon privilegiado.")
            return true
        }

        guard client.open() else { return false }
        defer { client.close() }
        canControlHardware = client.writeKeyData("F0Md", bytes: [0])
        if !canControlHardware {
            AppLog.log("[FanController] Sin privilegios: las escrituras al SMC requieren root.")
        }
        return canControlHardware
    }

    /// Recalcula los privilegios sin cachear (p.ej. cuando el daemon se instala
    /// o se cae durante la sesión).
    @discardableResult
    func recheckPrivileges() -> Bool {
        privilegeChecked = false
        return checkPrivileges()
    }

    /// Fija la velocidad de un ventilador dejándolo en modo manual.
    /// Omite la escritura si la velocidad no ha cambiado desde la última vez.
    func setSpeed(_ rpm: Double, toFan index: Int) {
        guard canControlHardware || checkPrivileges() else { return }
        if lastApplied[index] == rpm { return }

        if let daemon, daemon.isAvailable {
            daemon.setFanSpeed(fanIndex: index, rpm: rpm) { [weak self] ok in
                if ok {
                    self?.lastApplied[index] = rpm
                    AppLog.log("[FanController] F\(index) manual, velocidad = \(Int(rpm)) RPM (daemon)")
                }
            }
            return
        }

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
        if let daemon, daemon.isAvailable {
            daemon.restoreSystemControl(fanIndex: index) { [weak self] ok in
                if ok {
                    self?.lastApplied.removeValue(forKey: index)
                    AppLog.log("[FanController] F\(index) restaurado al control del sistema (daemon)")
                }
            }
            return
        }

        guard client.open() else { return }
        defer { client.close() }
        let key = "F\(index)"
        if client.writeKeyData(key + "Md", bytes: [0]) {
            lastApplied.removeValue(forKey: index)
            AppLog.log("[FanController] F\(index) restaurado al control del sistema")
        }
    }
}
