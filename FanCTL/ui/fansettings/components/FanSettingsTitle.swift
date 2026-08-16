//
//  Title.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct FanSettingsTitle: View {
    let fanName: String
    let onClose: () -> Void

    public var body: some View {
        HStack {
            Image(systemName: "fanblades.fill")
                .font(.title)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fan settings")
                    .font(.title2)
                    .bold()
                Text(fanName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.10))
                    )
                    .glassEffect(
                        .regular.interactive(true),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .help("Close settings")
        }
        .padding(10)
    }
}
