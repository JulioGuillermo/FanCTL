import SwiftUI
import ServiceManagement

/// App general settings sheet: rescan interval,
/// temperature indicator and fan control via the privileged daemon.
struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var daemon: FanDaemonClient
    let sensors: [SensorInfo]
    @Environment(\.dismiss) var dismiss

    private let intervalOptions: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("FanCTL Settings")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Close") { dismiss() }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Hardware rescan")
                    .font(.headline)

                Text("How often sensors and fans are re-read.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Interval", selection: Binding(
                    get: { store.settings.refreshInterval },
                    set: { store.setRefreshInterval($0) }
                )) {
                    ForEach(intervalOptions, id: \.self) { seconds in
                        Text(seconds < 1 ? "0.5 seconds" : (seconds == 1 ? "1 second" : "\(Int(seconds)) seconds"))
                            .tag(seconds)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Max temperature indicator")
                    .font(.headline)

                Text("Choose which sensor feeds the max temperature shown at the top and in the menu bar.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Source sensor", selection: Binding(
                    get: { store.settings.maxTempSensorKey ?? "" },
                    set: { store.setMaxTempSensorKey($0.isEmpty ? nil : $0) }
                )) {
                    Text("Automatic (hottest sensor)").tag("")
                    ForEach(sensors, id: \.id) { sensor in
                        Text(sensor.rawKey).tag(sensor.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(sensors.isEmpty)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("FanCTL Daemon")
                    .font(.headline)

                Text("A privileged daemon writes the speed to the SMC. The Start button asks for your administrator password the first time.")
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
                        Text("Connected")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        Text("Not connected")
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
                    Text("Requesting administrator privileges… accept the system dialog.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let error = daemon.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Button("Uninstall daemon", role: .destructive) { uninstallDaemon() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .disabled(daemon.isRequestingPermissions)
            }

            Spacer()

            HStack {
                Spacer()
                Text("FanCTL · built \(buildDateText)")
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
            return "unknown"
        }
        return mtime.formatted(date: .abbreviated, time: .shortened)
    }

    private var statusText: String {
        switch daemon.daemonStatus {
        case .notRegistered:
            return "Not installed"
        case .enabled:
            return "Installed and active"
        case .requiresApproval:
            return "Requires approval"
        case .notFound:
            return "Daemon missing from bundle"
        @unknown default:
            return "Unknown status"
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
        if daemon.isAvailable { return "Stop" }
        if daemon.daemonStatus == .enabled { return "Start" }
        return "Install and start"
    }

    private func uninstallDaemon() {
        daemon.uninstallDaemon()
    }
}
