//
//  FanSettingSensorList.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingSensorList: View {
    let temperatureSensors: [SensorInfo]
    @Binding var config: FanSettings
    @State var sortMode: SensorSortMode = .byType
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sensors controlling this fan")
                    .font(.headline)
                Spacer()
                SensorSortMenu(sortMode: $sortMode)
                Button("All") { selectAll() }
                Button("None") {
                    config.selectedSensorKeys = []
                }
            }
            .font(.caption)

            if !temperatureSensors.isEmpty {
                SensorSelectionList(
                    sensors: temperatureSensors,
                    sortMode: $sortMode,
                    isSelected: {
                        config.selectedSensorKeys.contains(
                            $0.id
                        )
                    },
                    onToggle: { toggle($0) },
                    onSetSelected: {
                        setSelected($0, selected: $1)
                    }
                )
                .frame(minHeight: 240, maxHeight: .infinity)
                .clipped()
            } else {
                Text("No sensors detected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
    
    private func toggle(_ sensor: SensorInfo) {
        if let index = config.selectedSensorKeys.firstIndex(of: sensor.id) {
            config.selectedSensorKeys.remove(at: index)
        } else {
            config.selectedSensorKeys.append(sensor.id)
        }
    }

    private func setSelected(_ sensors: [SensorInfo], selected: Bool) {
        for sensor in sensors {
            if selected {
                if !config.selectedSensorKeys.contains(sensor.id) {
                    config.selectedSensorKeys.append(sensor.id)
                }
            } else {
                config.selectedSensorKeys.removeAll { $0 == sensor.id }
            }
        }
    }

    private func selectAll() {
        config.selectedSensorKeys = temperatureSensors.map(\.id)
    }
}
