import Foundation
import Darwin

/// Servicio del daemon: escucha conexiones XPC entrantes en el mach service
/// `com.jg.FanCTL.daemon` y aplica el control del ventilador escribiendo al SMC.
final class DaemonService: NSObject, NSXPCListenerDelegate, FanDaemonProtocol {
    private let listener: NSXPCListener
    private let smc = DaemonSMCClient()

    override init() {
        listener = NSXPCListener(machServiceName: FanDaemonServiceName.machService)
        super.init()
        listener.delegate = self
    }

    func start() {
        listener.resume()
        DaemonLog.log("[DaemonService] Daemon iniciado (pid \(getpid()))")
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Solo aceptar conexiones del binario principal de FanCTL.
        guard let path = processPath(pid: newConnection.processIdentifier),
              path.contains("/FanCTL.app/Contents/MacOS/FanCTL") else {
            DaemonLog.log("[DaemonService] Conexión rechazada (pid \(newConnection.processIdentifier)).")
            return false
        }
        DaemonLog.log("[DaemonService] Conexión aceptada de pid \(newConnection.processIdentifier).")

        newConnection.exportedInterface = NSXPCInterface(with: FanDaemonProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: - FanDaemonProtocol

    func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func setFanSpeed(fanIndex: Int, rpm: Double, reply: @escaping (Bool) -> Void) {
        var ok = false
        if smc.open() {
            ok = smc.setManualMode(fanIndex: fanIndex, rpm: rpm)
            smc.close()
        }
        if ok {
            DaemonLog.log("[DaemonService] F\(fanIndex) manual, velocidad = \(Int(rpm)) RPM")
        }
        reply(ok)
    }

    func restoreSystemControl(fanIndex: Int, reply: @escaping (Bool) -> Void) {
        var ok = false
        if smc.open() {
            ok = smc.writeKey("F\(fanIndex)Md", bytes: [0])
            smc.close()
        }
        if ok {
            DaemonLog.log("[DaemonService] F\(fanIndex) restaurado al control del sistema")
        }
        reply(ok)
    }
}

/// Nombre del mach service, compartido entre app y daemon.
enum FanDaemonServiceName {
    static let machService = "com.jg.FanCTL.daemon"
    static let plistName = "com.jg.FanCTL.daemon.plist"
}

/// Ruta del binario del proceso a partir de su pid (para validar al cliente XPC).
private func processPath(pid: Int32) -> String? {
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return String(cString: buffer)
}
