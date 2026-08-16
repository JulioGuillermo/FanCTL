import SwiftUI

/// UI component to display and control a fan.
struct FanRowView: View {
    let fan: FanInfo
    var mode: FanMode = .automatic
    var desiredRPM: Double? = nil
    var manualRPM: Double = 1500
    var minSpeedRPM: Double? = nil
    var maxSpeedRPM: Double? = nil
    var controlActive: Bool = false
    var isRequestingPermissions: Bool = false
    var onChangeMode: (FanMode) -> Void = { _ in }
    var onManualRPMChange: (Double) -> Void = { _ in }
    var onRequestControl: () -> Void = {}
    var onSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                SpinningFanIcon(id: String(fan.id), percentage: fan.percentage)
                    .foregroundColor(fan.statusColor)
                    .font(.system(size: 16))

                Text(fan.name)
                    .bold()
                    .font(.body)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(fan.currentRPM))")
                        .font(.system(.title3, design: .monospaced))
                        .bold()
                        .foregroundColor(fan.statusColor)

                    Text("RPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.glass)
                .help("Settings for \(fan.name)")
            }

            // Control mode selector (visible and direct)
            Picker("Mode", selection: Binding(
                get: { mode },
                set: { onChangeMode($0) }
            )) {
                ForEach(FanMode.allCases, id: \.self) { candidate in
                    Label(candidate.rawValue, systemImage: candidate.iconName)
                        .tag(candidate)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Manual speed slider
            if mode == .manual {
            HStack(spacing: 10) {
                Text("Speed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { manualRPM },
                            set: { onManualRPMChange($0) }
                        ),
                        in: (minSpeedRPM ?? fan.minRPM)...max((maxSpeedRPM ?? fan.maxRPM), (minSpeedRPM ?? fan.minRPM)),
                        step: 50
                    )

                    Text("\(Int(manualRPM))")
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, fan.statusColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(fan.percentage), height: 8)
                }
            }
            .frame(height: 8)

            // Speed being applied according to the mode
            if let desired = desiredRPM {
                HStack {
                    Label(String(format: "Control: %d RPM", Int(desired)), systemImage: mode.iconName)
                        .bold()
                        .foregroundColor(controlActive ? .blue : .secondary)

                    Spacer()

                    if !controlActive {
                        if isRequestingPermissions {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Requesting permissions…")
                            }
                            .font(.caption2)
                        } else {
                            Button("Start control") { onRequestControl() }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                        }
                    }
                }
                .font(.caption2)
            }

            HStack {
                Text("Min: \(Int(fan.minRPM))")

                Spacer()

                if let target = fan.targetRPM {
                    Text("SMC target: \(Int(target)) RPM")
                        .foregroundColor(.blue)
                    Spacer()
                }

                Text("Max: \(Int(fan.maxRPM))")

                Spacer()

                Text(fan.percentageString)
                    .bold()
                    .foregroundColor(fan.statusColor)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        // Specular edge: sharp top highlight + thin glass rim
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.20), radius: 10, y: 4)
    }
}

#Preview {
    VStack(spacing: 12) {
        FanRowView(
            fan: FanInfo(
                id: 0,
                name: "Main Fan",
                currentRPM: 2450,
                minRPM: 1200,
                maxRPM: 6500,
                targetRPM: 2450,
                mode: .automatic
            ),
            mode: .automatic,
            desiredRPM: 4000,
            manualRPM: 3000,
            controlActive: true
        )

        FanRowView(
            fan: FanInfo(
                id: 1,
                name: "Secondary Fan (GPU)",
                currentRPM: 5100,
                minRPM: 1200,
                maxRPM: 6500,
                targetRPM: 5200,
                mode: .manual
            ),
            mode: .manual,
            desiredRPM: 3000,
            manualRPM: 3000,
            controlActive: true
        )
    }
    .padding()
    .frame(width: 480)
}
