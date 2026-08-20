//
//  MaxTemp.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct MaxTemp: View {
    let sensors: [SensorInfo]
    var maxTempSensorKeys: [String] = []

    private var maxTempSensor: SensorInfo? {
        if maxTempSensorKeys.isEmpty {
            return sensors.filter(\.isTemperature).max { $0.value < $1.value }
        }
        let pool = sensors.filter {
            maxTempSensorKeys.contains($0.id) && $0.isTemperature
        }
        return pool.max { $0.value < $1.value }
    }

    private var maxTempText: String {
        guard let sensor = maxTempSensor else { return "—" }
        return String(format: "%.1f °C", sensor.value)
    }

    private var maxTempColor: Color {
        guard let sensor = maxTempSensor else { return .secondary }
        return TemperatureIndicator.tempColor(for: sensor.value)
    }

    private var maxTempIcon: String {
        guard let sensor = maxTempSensor else { return "thermometer.medium" }
        return TemperatureIndicator.iconName(for: sensor.value)
    }

    private var maxTempSourceName: String {
        guard let sensor = maxTempSensor else { return "No data" }
        return maxTempSensorKeys.isEmpty
            ? "Auto · \(sensor.rawKey)" : sensor.rawKey
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label(maxTempText, systemImage: maxTempIcon)
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .foregroundColor(maxTempColor)
                    Text(maxTempSourceName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(sensors.count) active")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
        }
    }
}

#Preview {
    MaxTemp(
        sensors: [
            SensorInfo(
                id: "Sensor1",
                rawKey: "Key1",
                value: 54.2,
                source: .smc,
                category: .gpu,
                thermalZone: "CPU TZ",
                usagePage: 1,
                usage: 2,
                descriptionText: "hello",
                unit: "C",
            )
        ]
    )
}
