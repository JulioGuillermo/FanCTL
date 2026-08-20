//
//  StatusIndicator.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct StatusIndicator: View {
    let isConnected: Bool
    let connectionStatus: String
    let controlActive: Bool

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(connectionStatus)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if controlActive {
                Text("Control active")
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            } else {
                Text("Control requires root")
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

#Preview {
    StatusIndicator(isConnected: true, connectionStatus: "Connected", controlActive: true)
    StatusIndicator(isConnected: false, connectionStatus: "Disconnected", controlActive: false)
}
