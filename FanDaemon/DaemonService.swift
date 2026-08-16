import Foundation
import Darwin

/// Daemon service: listens for incoming XPC connections on the mach service
/// `com.jg.FanCTL.daemon` and applies fan control by writing to the SMC.
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
        DaemonLog.log("[DaemonService] Daemon started (pid \(getpid()))")
        if smc.open() {
            smc.dumpFanKeys()
            smc.close()
        }
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Only accept connections from the main FanCTL binary.
        guard let path = processPath(pid: newConnection.processIdentifier),
              path.contains("/FanCTL.app/Contents/MacOS/FanCTL") else {
            DaemonLog.log("[DaemonService] Connection rejected (pid \(newConnection.processIdentifier)).")
            return false
        }
        DaemonLog.log("[DaemonService] Connection accepted from pid \(newConnection.processIdentifier).")

        newConnection.exportedInterface = NSXPCInterface(with: FanDaemonProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: - FanDaemonProtocol

    func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func shutdown(reply: @escaping (Bool) -> Void) {
        DaemonLog.log("[DaemonService] Shutting down at the request of the app.")
        reply(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exit(0)
        }
    }

    func setFanSpeed(fanIndex: Int, rpm: Double, reply: @escaping (Bool) -> Void) {
        var ok = false
        if smc.open() {
            ok = smc.setFanSpeed(fanIndex: fanIndex, rpm: rpm)
            smc.close()
        }
        if ok {
            DaemonLog.log("[DaemonService] F\(fanIndex) manual, speed = \(Int(rpm)) RPM")
        } else {
            DaemonLog.log("[DaemonService] ERROR: could not set F\(fanIndex) a \(Int(rpm)) RPM")
        }
        reply(ok)
    }

    func restoreSystemControl(fanIndex: Int, reply: @escaping (Bool) -> Void) {
        var ok = false
        if smc.open() {
            ok = smc.restoreSystemControl(fanIndex: fanIndex)
            smc.close()
        }
        if ok {
            DaemonLog.log("[DaemonService] F\(fanIndex) restored to system control")
        } else {
            DaemonLog.log("[DaemonService] ERROR: could not restore F\(fanIndex)")
        }
        reply(ok)
    }
}

/// Mach service name, shared between app and daemon.
enum FanDaemonServiceName {
    static let machService = "com.jg.FanCTL.daemon"
    static let plistName = "com.jg.FanCTL.daemon.plist"
}

/// Process binary path from its pid (to validate the XPC client).
private func processPath(pid: Int32) -> String? {
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return String(cString: buffer)
}
