import Foundation
import ServiceManagement
internal import Combine

/// Cliente del daemon privilegiado de FanCTL.
///
/// Conecta con el mach service `com.jg.FanCTL.daemon` y expone el control
/// remoto del ventilador cuando el daemon está instalado y corriendo como root.
///
/// Todo el control de instalación/inicio/parada se reduce a un único método:
/// `toggle()`, que decide según el estado real del daemon:
/// - no instalado → lo instala (pide contraseña de administrador);
/// - instalado pero parado → lo arranca;
/// - corriendo → lo detiene.
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
    private var heartbeatTimer: Timer?

    init() {
        refreshStatus()
        connect()
        startHeartbeat()
    }

    /// Sondea el daemon periódicamente para recuperar la conexión aunque se
    /// pierda algún ping inicial.
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, !self.stopRequested else { return }
            self.ping()
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer
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

    // MARK: - Botón único: Iniciar / Detener

    /// Instala, arranca o detiene el daemon según su estado actual.
    /// Pide contraseña de administrador solo cuando hace falta (instalar/arrancar).
    func toggle() {
        refreshStatus()
        if isAvailable {
            stopDaemon()
            return
        }
        startDaemon()
    }

    /// Instala (si hace falta) y arranca el daemon como root. Si ya está
    /// instalado y corriendo, solo reconecta.
    func startDaemon() {
        refreshStatus()
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true
        lastError = nil
        stopRequested = false
        AppLog.log("[DaemonClient] Arrancando/instalando el daemon…")

        if daemonStatus == .enabled {
            // Ya instalado: basta con arrancar el servicio y conectar.
            PrivilegedInstaller.start(completion: completion)
        } else {
            PrivilegedInstaller.install(completion: completion)
        }
    }

    /// Detiene el daemon vía XPC (no pide contraseña).
    func stopDaemon() {
        stopRequested = true
        isRequestingPermissions = false
        guard let proxy = proxy() else {
            connection?.invalidate()
            connection = nil
            isAvailable = false
            refreshStatus()
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
        isRequestingPermissions = false
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

    private func completion(ok: Bool, message: String?) {
        isRequestingPermissions = false
        if ok {
            lastError = nil
            stopRequested = false
            refreshStatus()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.connect()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self else { return }
                    if !self.isAvailable {
                        self.lastError = "El daemon no responde tras arrancar. Revisa /Library/Logs/FanCTL/fanctl-daemon.log"
                    }
                }
            }
        } else {
            lastError = message ?? "No se pudo completar la operación con el daemon."
            refreshStatus()
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

        // Esperar a que la conexión XPC se establezca antes del primer ping;
        // llamar a métodos inmediatamente tras resume() puede fallar.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.ping()
        }
    }

    func ping() {
        guard let proxy = proxy() else { return }
        proxy.ping { [weak self] ok in
            DispatchQueue.main.async {
                self?.isAvailable = ok
                self?.refreshStatus()
            }
        }
    }

    // MARK: - Control del ventilador (XPC)

    func setFanSpeed(fanIndex: Int, rpm: Double, completion: @escaping (Bool) -> Void) {
        guard let proxy = proxy() else {
            AppLog.log("[DaemonClient] setFanSpeed F\(fanIndex) cancelado: sin proxy XPC")
            completion(false)
            return
        }
        AppLog.log("[DaemonClient] Enviando setFanSpeed F\(fanIndex)=\(Int(rpm)) por XPC")
        proxy.setFanSpeed(fanIndex: fanIndex, rpm: rpm) { ok in
            AppLog.log("[DaemonClient] Respuesta setFanSpeed F\(fanIndex)=\(Int(rpm)) -> \(ok)")
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func restoreSystemControl(fanIndex: Int, completion: @escaping (Bool) -> Void) {
        guard let proxy = proxy() else {
            completion(false)
            return
        }
        proxy.restoreSystemControl(fanIndex: fanIndex) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    private func proxy() -> FanDaemonProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            DispatchQueue.main.async {
                AppLog.log("[DaemonClient] Error del proxy XPC: \(error.localizedDescription)")
                self?.isAvailable = false
                self?.lastError = error.localizedDescription
            }
        } as? FanDaemonProtocol
    }
}
