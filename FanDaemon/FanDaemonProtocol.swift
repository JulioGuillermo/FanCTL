import Foundation

/// XPC protocol between the FanCTL app and its privileged daemon.
///
/// It must match exactly the one defined in the app
/// (`FanCTL/FanDaemonProtocol.swift`), since each side is compiled in a
/// separate module.
@objc protocol FanDaemonProtocol {
    func setFanSpeed(fanIndex: Int, rpm: Double, reply: @escaping (Bool) -> Void)
    func restoreSystemControl(fanIndex: Int, reply: @escaping (Bool) -> Void)
    func ping(reply: @escaping (Bool) -> Void)
    func shutdown(reply: @escaping (Bool) -> Void)
}
