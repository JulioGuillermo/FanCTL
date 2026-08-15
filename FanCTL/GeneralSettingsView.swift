import SwiftUI

/// Hoja de ajustes generales de la app (por ahora solo el intervalo de reescaneo).
struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) var dismiss

    private let intervalOptions: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("Ajustes Generales")
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

            Spacer()
        }
        .padding()
        .frame(width: 420, height: 260)
    }
}
