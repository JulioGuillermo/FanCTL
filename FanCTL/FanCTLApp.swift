//
//  FanCTLApp.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 15/08/2026.
//

import SwiftUI

@main
struct FanCTLApp: App {
    @StateObject private var daemonClient: FanDaemonClient
    @StateObject private var fanController: FanController
    @StateObject private var statusBar: StatusBarController

    init() {
        let daemon = FanDaemonClient()
        let fan = FanController(daemon: daemon)
        _daemonClient = StateObject(wrappedValue: daemon)
        _fanController = StateObject(wrappedValue: fan)
        _statusBar = StateObject(wrappedValue: StatusBarController(daemon: daemon, fanController: fan))
    }

    var body: some Scene {
        WindowGroup("FanCTL", id: "main") {
            ContentView()
                .environmentObject(daemonClient)
                .environmentObject(fanController)
        }
    }
}
