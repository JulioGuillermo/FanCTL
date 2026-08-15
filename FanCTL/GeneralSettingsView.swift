import SwiftUI
import ServiceManagement

/// Hoja de ajustes generales de la app: intervalo de reescaneo y control del
/// ventilador mediante el daemon privilegiado.
struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var daemon: FanDaemonClient
    @Environment(\.dismiss) var dismiss

    @State private var actionMessage: String?

    private let intervalOptions: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("Ajustes de FanCTL")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Cerrar") { dismiss() }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Reescaneo del hardware")
                    .font(.headline)

                Text("Cada cuánto se releen sensores y ventiladores.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Intervalo", selection: Binding(
                    get: { store.settings.refreshInterval },
                    set: { store.setRefreshInterval($0) }
                )) {
                    ForEach(intervalOptions, id: \.self) { seconds in
                        Text(seconds < 1 ? "0.5 segundos" : (seconds == 1 ? "1 segundo" : "\(Int(seconds)) segundos"))
                            .tag(seconds)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Daemon de FanCTL")
                    .font(.headline)

                Text("Un daemon con privilegios de administrador escribe la velocidad en el SMC. La primera instalación pedirá tu contraseña de administrador.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.caption)
                        .bold()

                    Spacer()

                    if daemon.isAvailable {
                        Text("Conectado")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        Text("Sin conexión XPC")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 10) {
                    Button("Instalar / Actualizar") { installDaemon() }
                        .buttonStyle(.borderedProminent)

                    Button("Detener") { daemon.stopDaemon() }
                        .buttonStyle(.bordered)
                        .disabled(!daemon.isAvailable)

                    Button("Desinstalar") { uninstallDaemon() }
                        .buttonStyle(.bordered)

                    Button("Reintentar conexión") { daemon.ping() }
                        .buttonStyle(.bordered)
                }

                if let message = actionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if daemon.daemonStatus == .requiresApproval {
                    Text("Aproba el daemon en Ajustes del Sistema → General → Elementos de inicio y permisos.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Text("FanCTL · compilada \(buildDateText)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 460)
    }

    private var buildDateText: String {
        guard let url = Bundle.main.executableURL,
              let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return "desconocida"
        }
        return mtime.formatted(date: .abbreviated, time: .shortened)
    }

    private var statusText: String {
        switch daemon.daemonStatus {
        case .notRegistered:
            return "No instalado"
        case .enabled:
            return "Instalado y activo"
        case .requiresApproval:
            return "Requiere aprobación"
        case .notFound:
            return "Daemon ausente del bundle"
        @unknown default:
            return "Estado desconocido"
        }
    }

    private var statusColor: Color {
        switch daemon.daemonStatus {
        case .enabled:
            return .green
        case .requiresApproval:
            return .orange
        default:
            return .gray
        }
    }

    private func installDaemon() {
        daemon.startDaemon()
        if let error = daemon.lastError {
            actionMessage = error
        } else {
            actionMessage = "Solicitado. Revisa el diálogo de autenticación de administrador."
        }
    }

    private func uninstallDaemon() {
        daemon.uninstallDaemon()
        actionMessage = "Daemon desinstalado. El control pasa a depender de los permisos de la app."
    }
}
