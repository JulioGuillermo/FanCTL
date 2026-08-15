import AppKit
internal import Combine

/// Gestiona el indicador de la barra de menú.
///
/// El icono aparece únicamente mientras el daemon privilegiado está activo y
/// muestra el estado de los ventiladores (RPM aplicadas) con acciones rápidas.
final class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private let daemon: FanDaemonClient
    private let fanController: FanController
    private let menuTarget = AppMenuTarget()
    private var cancellables = Set<AnyCancellable>()

    init(daemon: FanDaemonClient, fanController: FanController) {
        self.daemon = daemon
        self.fanController = fanController

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
                if available { self.updateMenu() }
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

    private func updateMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "FanCTL — Daemon activo", action: nil, keyEquivalent: "")
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
