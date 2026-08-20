//
//  RootBanner.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct RootBanner: View {
    let controlActive: Bool
    let isRequestingPermissions: Bool
    let onRequestControl: () -> Void
    let controlError: String?

    public var body: some View {
        if !controlActive {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fan control disabled")
                            .font(.caption)
                            .bold()
                        Text(
                            "Background control requires administrator privileges."
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Start control") { onRequestControl() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                        .disabled(isRequestingPermissions)
                }
                .padding(10)
                .glassEffect(
                    .clear.tint(.black.opacity(0.60)),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.50),
                                    .white.opacity(0.15),
                                    .black.opacity(0.30),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 5
                        )
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            if let controlError {
                Text(controlError)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            if isRequestingPermissions {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Requesting administrator privileges…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }

    }
}
