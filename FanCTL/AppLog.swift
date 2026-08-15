//
//  AppLog.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 15/08/2026.
//

import Foundation

/// Logger mínimo a archivo para diagnóstico del escáner de ventiladores/sensores.
/// Escribe en ~/Library/Logs/FanCTL/fanctl.log
enum AppLog {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("Logs/FanCTL", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("fanctl.log")
    }()

    private static let lock = NSLock()

    static func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
