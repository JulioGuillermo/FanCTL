import SwiftUI
import ServiceManagement

/// Hoja de ajustes generales de la app: intervalo de reescaneo y control del
/// ventilador mediante el daemon privilegiado.
struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var daemon: FanDaemonClient
    @Environment(\.dismiss) var dismiss

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

                Text("Un daemon con privilegios de administrador escribe la velocidad en el SMC. El botón Iniciar pide tu contraseña de administrador la primera vez.")
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

                    if daemon.isRequestingPermissions {
                        ProgressView()
                            .controlSize(.small)
                    } else if daemon.isAvailable {
                        Text("Conectado")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        Text("Sin conexión")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }

                Button(action: { daemon.toggle() }) {
                    HStack {
                        Image(systemName: daemon.isAvailable ? "stop.circle.fill" : "play.circle.fill")
                        Text(primaryButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(daemon.isAvailable ? .red : .blue)
                .disabled(daemon.isRequestingPermissions)

                if daemon.isRequestingPermissions {
                    Text("Solicitando permisos de administrador… acepta el diálogo del sistema.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let error = daemon.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Button("Desinstalar el daemon", role: .destructive) { uninstallDaemon() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .disabled(daemon.isRequestingPermissions)
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

    private var primaryButtonTitle: String {
        if daemon.isAvailable { return "Detener" }
        if daemon.daemonStatus == .enabled { return "Iniciar" }
        return "Instalar e iniciar"
    }

    private func uninstallDaemon() {
        daemon.uninstallDaemon()
    }
}
