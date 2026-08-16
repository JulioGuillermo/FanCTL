import SwiftUI
import ServiceManagement

/// App general settings sheet: rescan interval,
/// temperature indicator and fan control via the privileged daemon.
struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var daemon: FanDaemonClient
    let sensors: [SensorInfo]
    @Environment(\.dismiss) var dismiss

    @State private var sortMode: SensorSortMode = .alphabetical

    private let intervalOptions: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 30, 60]

    private var temperatureSensors: [SensorInfo] {
        sensors.filter(\.isTemperature)
    }

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

                Text("Choose which sensors feed the max temperature shown at the top and in the menu bar. If none are selected, the hottest sensor is used.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Button(action: { store.setMaxTempSensorKeys([]) }) {
                        HStack(spacing: 10) {
                            Image(systemName: store.settings.maxTempSensorKeys.isEmpty ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundColor(store.settings.maxTempSensorKeys.isEmpty ? .blue : .secondary)
                            Image(systemName: "sparkles")
                                .font(.body)
                                .foregroundColor(.blue)
                                .frame(width: 22)
                            Text("Automatic (hottest sensor)")
                                .font(.system(.body))
                                .bold()
                                .strikethrough(!store.settings.maxTempSensorKeys.isEmpty, color: .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Use the hottest sensor automatically.")

                    Spacer()
                    SensorSortMenu(sortMode: $sortMode)
                }

                if !temperatureSensors.isEmpty {
                    HStack {
                        Text("Sensors: \(store.settings.maxTempSensorKeys.count)/\(temperatureSensors.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("All") { store.setMaxTempSensorKeys(temperatureSensors.map(\.id)) }
                        Button("None") { store.setMaxTempSensorKeys([]) }
                    }
                    .font(.caption)

                    SensorSelectionList(
                        sensors: temperatureSensors,
                        sortMode: $sortMode,
                        isSelected: { store.settings.maxTempSensorKeys.contains($0.id) },
                        onToggle: { toggleMaxTempSensor($0) },
                        onSetSelected: { setMaxTempSensors($0, selected: $1) }
                    )
                    .frame(minHeight: 200, maxHeight: 300)
                    .clipped()
                } else {
                    Text("No sensors detected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

    private func toggleMaxTempSensor(_ sensor: SensorInfo) {
        var keys = store.settings.maxTempSensorKeys
        if let index = keys.firstIndex(of: sensor.id) {
            keys.remove(at: index)
        } else {
            keys.append(sensor.id)
        }
        store.setMaxTempSensorKeys(keys)
    }

    private func setMaxTempSensors(_ sensors: [SensorInfo], selected: Bool) {
        var keys = store.settings.maxTempSensorKeys
        if selected {
            for sensor in sensors where !keys.contains(sensor.id) {
                keys.append(sensor.id)
            }
        } else {
            for sensor in sensors {
                keys.removeAll { $0 == sensor.id }
            }
        }
        store.setMaxTempSensorKeys(keys)
    }

    private func uninstallDaemon() {
        daemon.uninstallDaemon()
    }
}
