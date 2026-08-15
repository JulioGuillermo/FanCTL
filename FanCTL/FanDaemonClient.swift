import Foundation
internal import Combine

/// Cliente XPC del daemon privilegiado de FanCTL.
///
/// Conecta con el mach service `com.jg.FanCTL.daemon` y expone el control
/// remoto del ventilador cuando el daemon está instalado y registrado.
/// Expone `isAvailable` para que la UI sepa si se está controlando a través
/// del daemon o directamente.
final class FanDaemonClient: ObservableObject {
    static let machServiceName = "com.jg.FanCTL.daemon"
    /// Nombre del plist dentro de `Contents/Library/LaunchDaemons` del bundle.
    static let plistName = "com.jg.FanCTL.daemon.plist"

    @Published private(set) var isAvailable = false
    @Published private(set) var lastError: String?

    private var connection: NSXPCConnection?

    init() {
        connect()
    }

    private func connect() {
        connection?.invalidate()

        let connection = NSXPCConnection(machServiceName: Self.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FanDaemonProtocol.self)
        connection.interruptionHandler = { [weak self] in
            // El daemon se cayó: marcar no disponible y reintentar conectarse.
            DispatchQueue.main.async {
                self?.connection?.invalidate()
                self?.connection = nil
                self?.isAvailable = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.connect()
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
        guard let proxy = proxy() else { return }
        proxy.ping { [weak self] ok in
            DispatchQueue.main.async {
                self?.isAvailable = ok
                if !ok { self?.lastError = "Sin respuesta del daemon." }
            }
        }
    }

    func setFanSpeed(fanIndex: Int, rpm: Double, completion: @escaping (Bool) -> Void) {
        guard let proxy = proxy() else {
            completion(false)
            return
        }
        proxy.setFanSpeed(fanIndex: fanIndex, rpm: rpm) { ok in
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
                self?.isAvailable = false
                self?.lastError = error.localizedDescription
            }
        } as? FanDaemonProtocol
    }
}
