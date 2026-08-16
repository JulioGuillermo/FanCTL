//
//  SensorList.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct SensorList: View {
    let sensors: [SensorInfo]
    @Binding var selectedSensor: SensorInfo?
    @State private var sortMode: SensorSortMode = .hottest

    private var sortedSensorsList: [SensorInfo] {
        sortedSensors(sensors, by: sortMode)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !sensors.isEmpty {
                HStack {
                    Text("Hardware sensors")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                    Spacer()
                    SensorSortMenu(sortMode: $sortMode)
                }
                .padding(.horizontal, 12)
                .padding(.top, 2)

                List(sortedSensorsList, id: \.id) { sensor in
                    SensorRowView(
                        sensor: sensor,
                        onTapDetails: { selectedSensor = sensor }
                    )
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No sensor data")
                        .font(.headline)
                    Text("Waiting for the first hardware read.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    SensorList(
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
            ),
            SensorInfo(
                id: "Sensor2",
                rawKey: "Key2",
                value: 53.2,
                source: .smc,
                category: .gpu,
                thermalZone: "CPU TZ",
                usagePage: 1,
                usage: 2,
                descriptionText: "hello",
                unit: "C",
            ),
            SensorInfo(
                id: "Sensor3",
                rawKey: "Key3",
                value: 58.2,
                source: .smc,
                category: .gpu,
                thermalZone: "CPU TZ",
                usagePage: 1,
                usage: 2,
                descriptionText: "hello",
                unit: "C",
            ),
            SensorInfo(
                id: "Sensor4",
                rawKey: "Key4",
                value: 56.2,
                source: .smc,
                category: .gpu,
                thermalZone: "CPU TZ",
                usagePage: 1,
                usage: 2,
                descriptionText: "hello",
                unit: "C",
            )
        ],
        selectedSensor: .constant(nil),
    )
}
