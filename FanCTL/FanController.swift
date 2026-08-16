import Foundation
internal import Combine

/// Controls the real fan speed by writing to AppleSMC.
///
/// The control protocol is the classic one: in manual mode (`F{i}Md = 1`)
/// the firmware sets the fan to the speed of `F{i}Mn`. Writing to the SMC
/// requires root privileges (without them `IOConnectCallStructMethod` returns
/// `kIOReturnNotPrivileged`), so this controller detects and exposes that
/// situation.
///
/// When the privileged daemon is available (`FanDaemonClient.isAvailable`)
/// control is delegated to it via XPC; otherwise direct writing is attempted.
final class FanController: ObservableObject {
    private let client: SMCClient
    private let daemon: FanDaemonClient?
    @Published private(set) var canControlHardware = false
    /// Speed applied to each fan (to show the state in the UI).
    @Published private(set) var appliedSpeeds: [Int: Double] = [:]
    private var privilegeChecked = false
    private var lastApplied: [Int: Double] = [:]

    init(client: SMCClient = SMCClient(), daemon: FanDaemonClient? = nil) {
        self.client = client
        self.daemon = daemon
    }

    /// Checks whether the SMC can be written to. If the daemon responds, control
    /// already exists; otherwise it tries a harmless write (F0Md = 0, auto mode).
    /// Caches the result.
    @discardableResult
    func checkPrivileges() -> Bool {
        if privilegeChecked { return canControlHardware }
        privilegeChecked = true

        if let daemon, daemon.isAvailable {
            canControlHardware = true
            AppLog.log("[FanController] Control through the privileged daemon.")
            return true
        }

        guard client.open() else { return false }
        defer { client.close() }
        canControlHardware = client.writeKeyData("F0Md", bytes: [0])
        if !canControlHardware {
            AppLog.log("[FanController] No privileges: SMC writes require root.")
        }
        return canControlHardware
    }

    /// Recalculates privileges without caching (e.g. when the daemon is installed
    /// or it goes down during the session).
    @discardableResult
    func recheckPrivileges() -> Bool {
        privilegeChecked = false
        return checkPrivileges()
    }

    /// Sets a fan's speed, leaving it in manual mode.
    /// Skips the write if the speed has not changed since last time.
    ///
    /// If the daemon is available, delegate to it immediately (it does not depend
    /// on the privileges cache, which may be stale when the app starts).
    func setSpeed(_ rpm: Double, toFan index: Int) {
        if let daemon, daemon.isAvailable {
            if lastApplied[index] == rpm { return }
            daemon.setFanSpeed(fanIndex: index, rpm: rpm) { [weak self] ok in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if ok {
                        self.lastApplied[index] = rpm
                        self.appliedSpeeds[index] = rpm
                        self.canControlHardware = true
                        AppLog.log("[FanController] F\(index) manual, speed = \(Int(rpm)) RPM (daemon)")
                    } else {
                        self.canControlHardware = false
                        AppLog.log("[FanController] F\(index): the daemon could not write the speed.")
                    }
                }
            }
            return
        }

        guard canControlHardware || checkPrivileges() else { return }
        if lastApplied[index] == rpm { return }

        guard client.open() else { return }
        defer { client.close() }

        let key = "F\(index)"
        let fltBytes = withUnsafeBytes(of: Float(rpm)) { Array($0) }

        if client.writeKeyData(key + "Md", bytes: [1]) {
            lastApplied[index] = rpm
            appliedSpeeds[index] = rpm
            AppLog.log("[FanController] F\(index) manual, speed = \(Int(rpm)) RPM")
        }
        client.writeKeyData(key + "Tg", bytes: fltBytes)
    }

    /// Returns fan control to the system (automatic mode).
    func restoreSystemControl(toFan index: Int) {
        if let daemon, daemon.isAvailable {
            daemon.restoreSystemControl(fanIndex: index) { [weak self] ok in
                if ok {
                    self?.lastApplied.removeValue(forKey: index)
                    self?.appliedSpeeds.removeValue(forKey: index)
                    AppLog.log("[FanController] F\(index) restored to system control (daemon)")
                }
            }
            return
        }

        guard client.open() else { return }
        defer { client.close() }
        let key = "F\(index)"
        if client.writeKeyData(key + "Md", bytes: [0]) {
            lastApplied.removeValue(forKey: index)
            appliedSpeeds.removeValue(forKey: index)
            AppLog.log("[FanController] F\(index) restored to system control")
        }
    }
}
