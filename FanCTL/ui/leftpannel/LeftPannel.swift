//
//  LeftPannel.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

struct LeftPannel: View {
    let sensors: [SensorInfo]
    @Binding var selectedSensor: SensorInfo?
    var maxTempSensorKeys: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MaxTemp(sensors: sensors, maxTempSensorKeys: maxTempSensorKeys)
            SensorList(sensors: sensors, selectedSensor: $selectedSensor)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Title()
            }
        }
        .navigationTitle("FanCTL")
    }
}
