import AppKit
internal import Combine
import SwiftUI

/// Manages the menu bar indicator.
///
/// The icon only appears while the privileged daemon is active and
/// shows the max temperature and fan RPMs next to the icon,
/// plus a menu with quick actions.
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
        statusItem = item

        menuTarget.onStopDaemon = { [weak self] in
            self?.daemon.stopDaemon()
        }

        // Icon only while the daemon is available.
        daemon.$isAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] available in
                guard let self else { return }
                self.statusItem?.isVisible = available
                self.updateStatusTitle()
            }
            .store(in: &cancellables)

        // Text next to the icon: max temp and RPM of each fan.
        Publishers.CombineLatest(monitor.$maxTemperature, monitor.$fanSpeeds)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusTitle()
            }
            .store(in: &cancellables)

        // Keep the RPMs up to date in the menu.
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
            button.attributedTitle = NSAttributedString()
            return
        }

        let attr = NSMutableAttributedString()

        // Temperature icon (by tier) + value
        if let max = monitor.maxTemperature {
            let color = TemperatureIndicator.color(for: max)
            let symbol = TemperatureIndicator.iconName(for: max)
            attr.append(NSAttributedString(attachment: attachment(symbol: symbol, size: 13, color: NSColor(color))))
            attr.append(NSAttributedString(
                string: String(format: " %.1f°C", max),
                attributes: [.foregroundColor: NSColor(color)]
            ))
        }

        // Fan icon + speed
        let rpmValues = monitor.fanSpeeds.keys.sorted().compactMap { monitor.fanSpeeds[$0] }
        if !rpmValues.isEmpty {
            if attr.length > 0 { attr.append(NSAttributedString(string: "  ")) }
            attr.append(NSAttributedString(attachment: attachment(symbol: "fanblades.fill", size: 13, color: nil)))
            let rpmText = rpmValues.map { String(Int($0)) }.joined(separator: "/")
            attr.append(NSAttributedString(string: " \(rpmText)"))
        }

        button.attributedTitle = attr
    }

    private func attachment(symbol: String, size: CGFloat, color: NSColor?) -> NSTextAttachment {
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()
        var image = base
        if let color {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
                .applying(.init(paletteColors: [color]))
            image = base.withSymbolConfiguration(config) ?? base
        } else {
            image = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: .regular)) ?? base
            image.isTemplate = true
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -2, width: size, height: size)
        return attachment
    }

    private func updateMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false

        var headerTitle = "FanCTL — Daemon active"
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
                    title: "Fan \(index): \(Int(fanController.appliedSpeeds[index] ?? 0)) RPM",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open FanCTL", action: #selector(AppMenuTarget.openMainWindow), keyEquivalent: "o")
        open.target = menuTarget
        menu.addItem(open)

        let stop = NSMenuItem(title: "Stop daemon", action: #selector(AppMenuTarget.stopDaemon), keyEquivalent: "")
        stop.target = menuTarget
        menu.addItem(stop)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit FanCTL", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
    }
}

/// Target of the status bar menu actions.
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
