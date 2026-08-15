import AppKit
internal import Combine

/// Gestiona el indicador de la barra de menú.
///
/// El icono aparece únicamente mientras el daemon privilegiado está activo y
/// muestra la temperatura máxima y las RPM de los ventiladores junto al icono,
/// además de un menú con acciones rápidas.
final class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private let daemon: FanDaemonClient
    private let fanController: FanController
    private let monitor: HardwareMonitor
    private let menuTarget = AppMenuTarget()
    private var cancellables = Set<AnyCancellable>()

    init(daemon: FanDaemonClient, fanController: FanController, monitor: HardwareMonitor) {
        self.daemon = daemon
        self.fanController = fanController
        self.monitor = monitor

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "fanblades.fill", accessibilityDescription: "FanCTL")
            button.image?.isTemplate = true
        }
        item.isVisible = false
        statusItem = item

        menuTarget.onStopDaemon = { [weak self] in
            self?.daemon.stopDaemon()
        }

        // Icono solo mientras el daemon está disponible.
        daemon.$isAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] available in
                guard let self else { return }
                self.statusItem?.isVisible = available
                self.updateStatusTitle()
            }
            .store(in: &cancellables)

        // Texto junto al icono: temp máxima y RPM de cada ventilador.
        Publishers.CombineLatest(monitor.$maxTemperature, monitor.$fanSpeeds)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusTitle()
            }
            .store(in: &cancellables)

        // Mantener las RPM al día en el menú.
        fanController.$appliedSpeeds
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        guard daemon.isAvailable else {
            button.title = ""
            return
        }

        var parts: [String] = []
        if let max = monitor.maxTemperature {
            parts.append(String(format: "%.1f°C", max))
        }
        let rpmValues = monitor.fanSpeeds.keys.sorted().compactMap { monitor.fanSpeeds[$0] }
        if !rpmValues.isEmpty {
            let rpmText = rpmValues.map { String(Int($0)) }.joined(separator: "/")
            parts.append("\(rpmText) RPM")
        }
        button.title = parts.joined(separator: "  ")
    }

    private func updateMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false

        var headerTitle = "FanCTL — Daemon activo"
        if let max = monitor.maxTemperature {
            headerTitle += String(format: " · %.1f°C", max)
        }
        let header = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let fans = fanController.appliedSpeeds.keys.sorted()
        if !fans.isEmpty {
            menu.addItem(.separator())
            for index in fans {
                let item = NSMenuItem(
                    title: "Ventilador \(index): \(Int(fanController.appliedSpeeds[index] ?? 0)) RPM",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let open = NSMenuItem(title: "Abrir FanCTL", action: #selector(AppMenuTarget.openMainWindow), keyEquivalent: "o")
        open.target = menuTarget
        menu.addItem(open)

        let stop = NSMenuItem(title: "Detener daemon", action: #selector(AppMenuTarget.stopDaemon), keyEquivalent: "")
        stop.target = menuTarget
        menu.addItem(stop)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir de FanCTL", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
    }
}

/// Objetivo de las acciones del menú de la barra de estado.
private final class AppMenuTarget: NSObject {
    var onStopDaemon: () -> Void = {}

    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc func stopDaemon() {
        onStopDaemon()
    }
}
