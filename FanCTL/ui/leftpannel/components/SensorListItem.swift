//
//  SensorListItem.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

struct SensorRowView: View {
    let sensor: SensorInfo
    var onTapDetails: () -> Void = {}

    private var temperatureColor: Color {
        guard sensor.isTemperature else { return .secondary }
        
        return TemperatureIndicator.tempColor(for: sensor.value)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: sensor.category.iconName)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(sensor.rawKey)
                    .font(.system(.body, design: .monospaced))
                    .bold()

                Text("\(SensorDescriptions.shortName(for: sensor.rawKey)) · \(sensor.source.rawValue)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .help(sensor.descriptionText)

            Spacer()

            Text(sensor.displayValue)
                .font(.system(.body, design: .monospaced))
                .bold()
                .foregroundColor(temperatureColor)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapDetails()
        }
    }
}
