//
//  SmokeParticles.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct SmokeParticles: View {
    private let particleCount = 60
    private let palette: [Color] = [
        .white,
        Color(red: 0.45, green: 0.75, blue: 1.0),
        Color(red: 0.75, green: 0.55, blue: 1.0),
        Color(red: 0.45, green: 1.0, blue: 0.95)
    ]

    public var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.addFilter(.blur(radius: 6))
                let w = size.width
                let h = size.height

                for i in 0..<particleCount {
                    let seed = Double(i) * 0.618033988749895
                    let lane = (seed * 7.0).truncatingRemainder(dividingBy: 1.0)
                    let speed = 0.015 + 0.025 * lane
                    let duration = 9.0 + 5.0 * ((seed * 13.0).truncatingRemainder(dividingBy: 1.0))
                    let progress = ((time * speed) + seed).truncatingRemainder(dividingBy: 1.0)

                    let xBase = ((seed * 31.7).truncatingRemainder(dividingBy: 1.0)) * w
                    let sway = sin(time * 0.5 + seed * 40.0) * w * 0.07
                    let x = xBase + sway

                    let y = h * (1 - progress) + duration * 0
                    let radius = 16.0 + 30.0 * ((seed * 9.0).truncatingRemainder(dividingBy: 1.0))

                    // Soft fade in at the bottom, fade out at the top.
                    let fade = sin(progress * .pi)
                    let color = palette[i % palette.count].opacity(0.10 * fade)

                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}
