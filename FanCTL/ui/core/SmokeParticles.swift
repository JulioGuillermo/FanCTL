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
                ctx.addFilter(.blur(radius: 4))
                let w = size.width
                let h = size.height
                // Vortex aligned with the decorative fan position
                let cx = w * 0.5
                let cy = h * 0.42
                // Spawn/reach radius so particles start off-screen and exit off-screen
                let maxReach = max(w, h) * 0.75

                for i in 0..<particleCount {
                    let seed = Double(i) * 0.618033988749895
                    let lane = (seed * 7.0).truncatingRemainder(dividingBy: 1.0)
                    let speed = 0.03 + 0.045 * lane
                    let progress = ((time * speed) + seed).truncatingRemainder(dividingBy: 1.0)

                    // Cycle split: inward spiral first, then blown outward
                    let inNorm = min(progress / 0.45, 1.0)
                    let outNorm = (progress - 0.45) / 0.55

                    // Per-particle variation so the spirals never line up into one
                    // visible swirl: each one turns a different amount, at a
                    // different tightness, with a different wobble.
                    let turnsIn = (0.36 + 0.72 * frac(seed * 9.1)) * 2.0 * .pi
                    let turnsOut = (0.42 + 0.84 * frac(seed * 11.3)) * 2.0 * .pi
                    // Always > 1 so the radial speed eases to zero at the central
                    // boundary: the turnaround is a smooth valley, never a bounce.
                    let expB = 1.1 + 0.9 * frac(seed * 5.7)
                    // Outward leg: bigger exponent = slow start near the fan and
                    // accelerating drift towards the edges.
                    let expOut = 1.3 + 1.0 * frac(seed * 5.7)
                    let wobble = sin(time * (0.4 + 1.2 * frac(seed * 6.1)) + seed * 40.0) * (0.25 + 0.35 * frac(seed * 4.7))

                    // Where each particle enters the cycle: its own spawn distance
                    // and angle, so they never all start on the same ring.
                    let spawnScale = 0.55 + 0.55 * frac(seed * 13.7)
                    let baseAngle = (seed + 0.13 * frac(seed * 23.7)) * 2.0 * .pi

                    // Central exclusion zone: particles never reach the fan itself
                    let minReach = 0.16 * min(w, h) * (0.9 + 0.2 * frac(seed * 3.1))

                    // Radius: edge -> around the fan -> out of the screen
                    let radius: Double
                    let turns: Double
                    if progress < 0.45 {
                        radius = minReach + (maxReach * spawnScale - minReach) * pow(1.0 - inNorm, expB)
                        // The closer to the fan, the faster they spin
                        turns = turnsIn * pow(inNorm, 2.0)
                    } else {
                        radius = minReach + (maxReach - minReach) * pow(outNorm, expOut)
                        // Leaving the fan: rotation keeps winding down while the
                        // radial motion accelerates towards the screen edges.
                        turns = turnsIn + turnsOut * (1.0 - pow(1.0 - outNorm, 2.0))
                    }
                    let angle = baseAngle + wobble + turns

                    let x = cx + cos(angle) * radius
                    let y = cy + sin(angle) * radius

                    // Size = depth: smallest right at the fan, grows as it is blown
                    // away from the center and towards the viewer.
                    let size = progress < 0.45
                        ? 10.0 - 5.0 * inNorm
                        : 5.0 + 35.0 * outNorm

                    // Fade in while approaching, fade out when leaving the screen
                    let fadeIn = progress < 0.45 ? smoothstep(0.0, 0.08, progress) : 1.0
                    let fadeOut = progress > 0.85 ? smoothstep(1.0, 0.85, progress) : 1.0
                    let fade = fadeIn * fadeOut

                    let color = palette[i % palette.count].opacity(0.10 * fade)

                    let rect = CGRect(x: x - size, y: y - size, width: size * 2, height: size * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }

    private func frac(_ value: Double) -> Double {
        value - floor(value)
    }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
        return t * t * (3.0 - 2.0 * t)
    }
}
