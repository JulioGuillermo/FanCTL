import Foundation
import ServiceManagement
internal import Combine

/// Cliente del daemon privilegiado de FanCTL.
///
/// Conecta con el mach service `com.jg.FanCTL.daemon` y expone el control
/// remoto del ventilador cuando el daemon está instalado y registrado.
/// También permite iniciarlo (`SMAppService.register`) y detenerlo (el daemon
/// sale por petición vía XPC).
final class FanDaemonClient: ObservableObject {
    static let machServiceName = "com.jg.FanCTL.daemon"
    /// Nombre del plist dentro de `Contents/Library/LaunchDaemons` del bundle.
    static let plistName = "com.jg.FanCTL.daemon.plist"

    @Published private(set) var isAvailable = false
    @Published private(set) var daemonStatus: SMAppService.Status = .notRegistered
    @Published private(set) var lastError: String?
    @Published private(set) var isRequestingPermissions = false

    private var connection: NSXPCConnection?
    private var stopRequested = false

    init() {
        refreshStatus()
        connect()
    }

    /// Lee el estado de instalación del daemon en launchd, combinando el
    /// registro vía SMAppService y la instalación clásica en
    /// `/Library/LaunchDaemons`.
    func refreshStatus() {
        let smStatus = SMAppService.daemon(plistName: Self.plistName).status
        let legacyStatus = SMAppService.statusForLegacyPlist(at: PrivilegedInstaller.legacyPlistURL)
        if smStatus == .enabled || legacyStatus == .enabled {
            daemonStatus = .enabled
        } else {
            daemonStatus = smStatus
        }
    }

    // MARK: - Conexión XPC

    private func connect() {
        connection?.invalidate()

        let connection = NSXPCConnection(machServiceName: Self.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FanDaemonProtocol.self)
        connection.interruptionHandler = { [weak self] in
            // El daemon se cayó. Si no se pidió detenerlo, reintentar conectarse.
            DispatchQueue.main.async {
                guard let self, !self.stopRequested else { return }
                self.connection?.invalidate()
                self.connection = nil
                self.isAvailable = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.connect()
                }
            }
        }
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.isAvailable = false }
        }

        self.connection = connection
        connection.resume()
        ping()
    }

    func ping() {
        guard !stopRequested, let proxy = proxy() else { return }
        proxy.ping { [weak self] ok in
            DispatchQueue.main.async {
                self?.isAvailable = ok
                self?.refreshStatus()
            }
        }
    }

    // MARK: - Control del ventilador (XPC)

    func setFanSpeed(fanIndex: Int, rpm: Double, completion: @escaping (Bool) -> Void) {
        guard !stopRequested, let proxy = proxy() else {
            completion(false)
            return
        }
        proxy.setFanSpeed(fanIndex: fanIndex, rpm: rpm) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func restoreSystemControl(fanIndex: Int, completion: @escaping (Bool) -> Void) {
        guard !stopRequested, let proxy = proxy() else {
            completion(false)
            return
        }
        proxy.restoreSystemControl(fanIndex: fanIndex) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    // MARK: - Iniciar / Detener

    /// Instala el daemon como root (pide contraseña de administrador) y
    /// conecta con él.
    func startDaemon() {
        refreshStatus()
        guard daemonStatus != .enabled else {
            stopRequested = false
            connect()
            return
        }

        PrivilegedInstaller.install { [weak self] ok, message in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRequestingPermissions = false
                if ok {
                    self.lastError = nil
                    self.stopRequested = false
                    self.refreshStatus()
                    // La carga del daemon es asíncrona; intentar conectar tras un momento.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        guard let self else { return }
                        self.connect()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if !self.isAvailable {
                                self.lastError = "Daemon instalado, pero no responde. Reintenta la conexión o revisa el log del daemon."
                            }
                        }
                    }
                } else {
                    self.lastError = message ?? "No se pudo instalar el daemon."
                    self.refreshStatus()
                }
            }
        }
    }

    /// Solicita al sistema los permisos necesarios para controlar el ventilador.
    /// Instala el daemon como root (con prompt de administrador) o conecta si
    /// ya está instalado y activo.
    func requestPermissions() {
        refreshStatus()
        if daemonStatus == .enabled {
            stopRequested = false
            lastError = nil
            connect()
            return
        }
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true
        lastError = nil
        AppLog.log("[DaemonClient] Solicitando permisos de administrador…")
        startDaemon()
    }

    /// Pide al daemon que termine y corta la conexión. No desinstala el daemon
    /// (sigue registrado para volver a arrancarlo bajo demanda).
    func stopDaemon() {
        stopRequested = true
        guard let proxy = proxy() else {
            connection?.invalidate()
            connection = nil
            isAvailable = false
            return
        }
        proxy.shutdown { [weak self] _ in
            DispatchQueue.main.async {
                self?.connection?.invalidate()
                self?.connection = nil
                self?.isAvailable = false
                self?.refreshStatus()
            }
        }
    }

    /// Desinstala el daemon de launchd (pide contraseña de administrador) y
    /// corta la conexión.
    func uninstallDaemon() {
        stopRequested = true
        connection?.invalidate()
        connection = nil
        isAvailable = false
        try? SMAppService.daemon(plistName: Self.plistName).unregister()
        PrivilegedInstaller.uninstall { [weak self] ok, message in
            DispatchQueue.main.async {
                self?.lastError = ok ? nil : (message ?? "No se pudo desinstalar el daemon.")
                self?.refreshStatus()
            }
        }
    }

    private func proxy() -> FanDaemonProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            DispatchQueue.main.async {
                self?.isAvailable = false
                self?.lastError = error.localizedDescription
            }
        } as? FanDaemonProtocol
    }
}
