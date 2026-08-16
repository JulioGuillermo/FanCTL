import Foundation
import ServiceManagement
internal import Combine

/// FanCTL privileged daemon client.
///
/// Connects to the `com.jg.FanCTL.daemon` mach service and exposes remote
/// fan control when the daemon is installed and running as root.
///
/// All install/start/stop control is reduced to a single method:
/// `toggle()`, which decides based on the real daemon state:
/// - not installed → installs it (asks for the administrator password);
/// - installed but stopped → starts it;
/// - running → stops it.
final class FanDaemonClient: ObservableObject {
    static let machServiceName = "com.jg.FanCTL.daemon"
    /// Plist name inside the bundle's `Contents/Library/LaunchDaemons`.
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

    /// Periodically pings the daemon to recover the connection even if
    /// an initial ping is lost.
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, !self.stopRequested else { return }
            self.ping()
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer
    }

    /// Reads the daemon installation state in launchd, combining the
    /// SMAppService registration and the classic installation in
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

    // MARK: - Single button: Start / Stop

    /// Installs, starts or stops the daemon according to its current state.
    /// Only asks for the administrator password when needed (install/start).
    func toggle() {
        refreshStatus()
        if isAvailable {
            stopDaemon()
            return
        }
        startDaemon()
    }

    /// Installs (if needed) and starts the daemon as root. If it is already
    /// installed and running, it only reconnects.
    func startDaemon() {
        refreshStatus()
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true
        lastError = nil
        stopRequested = false
        AppLog.log("[DaemonClient] Starting/installing the daemon…")

        if daemonStatus == .enabled {
            // Already installed: just start the service and connect.
            PrivilegedInstaller.start(completion: completion)
        } else {
            PrivilegedInstaller.install(completion: completion)
        }
    }

    /// Stops the daemon via XPC (no password needed).
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

    /// Uninstalls the daemon from launchd (asks for the administrator password) and
    /// cuts the connection.
    func uninstallDaemon() {
        stopRequested = true
        isRequestingPermissions = false
        connection?.invalidate()
        connection = nil
        isAvailable = false
        try? SMAppService.daemon(plistName: Self.plistName).unregister()
        PrivilegedInstaller.uninstall { [weak self] ok, message in
            DispatchQueue.main.async {
                self?.lastError = ok ? nil : (message ?? "Could not uninstall the daemon.")
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
                        self.lastError = "daemon does not respond after starting. Check /Library/Logs/FanCTL/fanctl-daemon.log"
                    }
                }
            }
        } else {
            lastError = message ?? "Could not complete the operation with the daemon."
            refreshStatus()
        }
    }

    // MARK: - XPC connection

    private func connect() {
        connection?.invalidate()

        let connection = NSXPCConnection(machServiceName: Self.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FanDaemonProtocol.self)
        connection.interruptionHandler = { [weak self] in
            // The daemon went down. If stopping was not requested, retry connecting.
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

        // Wait for the XPC connection to be established before the first ping;
        // calling methods right after resume() can fail.
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

    // MARK: - Fan control (XPC)

    func setFanSpeed(fanIndex: Int, rpm: Double, completion: @escaping (Bool) -> Void) {
        guard let proxy = proxy() else {
            AppLog.log("[DaemonClient] setFanSpeed F\(fanIndex) cancelled: no XPC proxy")
            completion(false)
            return
        }
        AppLog.log("[DaemonClient] Sending setFanSpeed F\(fanIndex)=\(Int(rpm)) via XPC")
        proxy.setFanSpeed(fanIndex: fanIndex, rpm: rpm) { ok in
            AppLog.log("[DaemonClient] Response setFanSpeed F\(fanIndex)=\(Int(rpm)) -> \(ok)")
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
                AppLog.log("[DaemonClient] XPC proxy error: \(error.localizedDescription)")
                self?.isAvailable = false
                self?.lastError = error.localizedDescription
            }
        } as? FanDaemonProtocol
    }
}
