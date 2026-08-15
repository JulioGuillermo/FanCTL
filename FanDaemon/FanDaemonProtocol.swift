import Foundation

/// Protocolo XPC entre la app FanCTL y su daemon privilegiado.
///
/// Debe coincidir exactamente con el definido en la app
/// (`FanCTL/FanDaemonProtocol.swift`), ya que cada lado se compila en un
/// módulo distinto.
@objc protocol FanDaemonProtocol {
    func setFanSpeed(fanIndex: Int, rpm: Double, reply: @escaping (Bool) -> Void)
    func restoreSystemControl(fanIndex: Int, reply: @escaping (Bool) -> Void)
    func ping(reply: @escaping (Bool) -> Void)
}
