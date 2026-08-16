//
//  LiquidGlassDialog.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

extension View {
    /// Chrome for a floating Liquid Glass panel: material, bright bevel,
    /// projected shadow and rounded corners. Used to style the content of
    /// transparent settings windows.
    func liquidGlassPanel(cornerRadius: CGFloat = 24) -> some View {
        self
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1),
                                .clear,
                                .white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 15)
    }
}

/// Reusable centered container styled with Liquid Glass.
///
/// Shows a floating glass panel over a dimmed backdrop, with a bright bevel,
/// a soft projected shadow and a springy "liquid" scale transition. Content
/// is provided by the caller (typically a header with a Close action and the
/// dialog body); tapping the backdrop dismisses it.
struct LiquidGlassDialog<Content: View>: View {
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            if isPresented {
                // Dimmer behind the dialog: full-screen interactive backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismiss() }

                // Liquid Glass panel, forced above every other element
                VStack(spacing: 0) {
                    content()
                }
                .padding(24)
                // Light distortion: native material blurs the content behind it
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                // Inner bevel: bright edge that simulates the glass thickness
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.1),
                                    .clear,
                                    .white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                // Projected shadow: the dialog floats high above the content
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 15)
                // Guarantees macOS renders it above any native control
                .zIndex(1)
                // Liquid scale + fade transition
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPresented)
    }

    private func dismiss() {
        isPresented = false
        onDismiss?()
    }
}
