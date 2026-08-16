//
//  FanCTLApp.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 15/08/2026.
//

import SwiftUI

@main
struct FanCTLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var daemonClient: FanDaemonClient
    @StateObject private var fanController: FanController
    @StateObject private var hardwareMonitor: HardwareMonitor
    @StateObject private var statusBar: StatusBarController

    init() {
        let daemon = FanDaemonClient()
        let fan = FanController(daemon: daemon)
        let monitor = HardwareMonitor()
        _daemonClient = StateObject(wrappedValue: daemon)
        _fanController = StateObject(wrappedValue: fan)
        _hardwareMonitor = StateObject(wrappedValue: monitor)
        _statusBar = StateObject(wrappedValue: StatusBarController(daemon: daemon, fanController: fan, monitor: monitor))
    }

    var body: some Scene {
        WindowGroup("FanCTL", id: "main") {
            ContentView()
                .environmentObject(daemonClient)
                .environmentObject(fanController)
                .environmentObject(hardwareMonitor)
        }
        .defaultSize(width: 1100, height: 760)
        // Integrate the title bar with the content: the window background
        // extends to the top and only the traffic lights remain.
        .windowStyle(.hiddenTitleBar)
    }
}
