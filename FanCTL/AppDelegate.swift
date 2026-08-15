import AppKit
import SwiftUI

/// Mantiene la app viva en la barra de menú cuando se cierra la ventana
/// principal, de modo que el control del ventilador continúa (patrón de app
/// de barra de menú, tipo Stats/iStat). El cierre real (Cmd+Q o "Salir")
/// sigue devolviendo el control al sistema.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App sin Dock (LSUIElement): crear un menú mínimo para que Cmd+Q
        // cierre la app igualmente.
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Salir de FanCTL",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

/// Intercepta el cierre de la ventana principal para ocultarla en vez de
/// destruirla: la vista y el bucle de control siguen vivos en segundo plano.
struct WindowCloseHider: NSViewRepresentable {
    final class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
