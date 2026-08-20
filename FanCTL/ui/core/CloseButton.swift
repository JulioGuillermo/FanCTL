//
//  CloseButton.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

/// macOS-style traffic light close button: red circle that reveals
/// an X only while hovered.
struct CloseButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.red)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.black.opacity(0.60))
                    .opacity(isHovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isHovering)
            }
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Close")
        .padding(0)
    }
}
